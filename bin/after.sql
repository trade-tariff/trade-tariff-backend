-- This script refreshes all materialized views in the 'uk', 'xi', and 'public' schemas.
-- It dynamically determines the refresh order based on dependencies between materialized views
-- by parsing the view definitions to find references to other materialized views.
-- Dependencies are detected through text analysis of the view definition SQL.
-- If a refresh fails (e.g., due to locks or errors), it logs a notice and continues.
-- If a refresh exceeds a timeout (60s) we will backoff retry (up to 3 times)

VACUUM FULL ANALYZE;

DO $$
DECLARE
    current_mv text;       -- Variable to hold the current materialized view name
    start_time timestamp;  -- Timestamp to track start time for each refresh
    duration interval;     -- Interval to calculate refresh duration
    formatted_duration text;  -- Human-readable duration string (e.g., '0.019 seconds')
    overall_start timestamp := clock_timestamp();  -- Overall script start time

    -- Enhanced tracking variables
    total_views integer := 0;
    current_view_num integer := 0;
    success_count integer := 0;
    failure_count integer := 0;
    failed_views text[] := '{}';
    before_bytes bigint;
    after_bytes bigint;
    total_elapsed numeric;

    -- Retry variables
    max_retries integer := 3;
    retry_count integer;
    backoff_seconds integer;

    -- For summary table row
    rec record;
BEGIN
    -- Optimize memory for materialized view operations
    PERFORM set_config('maintenance_work_mem', '2GB', true);

    -- Create temporary table to store the ordered list of materialized views
    -- This table is dropped automatically at the end of the transaction (ON COMMIT DROP).
    CREATE TEMP TABLE ordered_mvs (
        mv_name text,
        depth integer,
        row_num integer
    ) ON COMMIT DROP;

    -- Create temp table for refresh summary
    CREATE TEMP TABLE refresh_summary (
        mv_name text,
        retries integer,
        before_bytes bigint,
        after_bytes bigint,
        elapsed_seconds numeric,
        status text
    ) ON COMMIT DROP;

    -- Build dependency information by parsing materialized view definitions
    -- We look for textual references to other materialized views in the definition SQL
    -- This approach works because PostgreSQL stores the view definition as text
    -- and views that reference other views will contain those references in their SQL
    CREATE TEMP TABLE temp_deps AS
    SELECT dependent.schemaname || '.' || dependent.matviewname AS dependent_view,
           referenced.schemaname || '.' || referenced.matviewname AS referenced_view
    FROM pg_matviews dependent
    JOIN pg_matviews referenced ON referenced.schemaname IN ('uk', 'xi', 'public')
        AND dependent.schemaname IN ('uk', 'xi', 'public')
        AND dependent.matviewname != referenced.matviewname
    WHERE (
        -- Look for explicit schema.table references in the view definition
        dependent.definition ILIKE '%' || referenced.schemaname || '.' || referenced.matviewname || '%'
        -- Also look for unqualified table references (assuming same schema context)
        OR dependent.definition ILIKE '%' || referenced.matviewname || '%'
    );

    -- Use a recursive Common Table Expression (CTE) to build a dependency tree
    -- This determines the correct refresh order: base views first, then dependent views
    WITH RECURSIVE dep_tree AS (
        -- Base case: Views that don't depend on any other materialized views (depth 0)
        -- These are "leaf" views that only reference base tables, not other materialized views
        SELECT mv.schemaname || '.' || mv.matviewname AS mv_name,
               0 AS depth
        FROM pg_matviews mv
        WHERE mv.schemaname IN ('uk', 'xi', 'public')
        AND NOT EXISTS (
            -- Check if this view appears as a dependent in our dependency table
            SELECT 1 FROM temp_deps td
            WHERE td.dependent_view = mv.schemaname || '.' || mv.matviewname
        )

        UNION ALL

        -- Recursive case: Views that depend on views from previous levels
        -- Each level of dependency increases the depth by 1
        SELECT td.dependent_view AS mv_name,
               dt.depth + 1 AS depth
        FROM dep_tree dt
        JOIN temp_deps td ON td.referenced_view = dt.mv_name
        WHERE dt.depth < 10  -- Prevent infinite recursion (max 10 levels of dependencies)
    )
    -- Insert unique view names into the ordered table with proper depth-based ordering
    -- Views at lower depths (fewer dependencies) are refreshed first
    INSERT INTO ordered_mvs (mv_name, depth, row_num)
    SELECT mv_name,
           MIN(depth) as depth,  -- Use minimum depth if a view appears at multiple levels
           ROW_NUMBER() OVER (ORDER BY MIN(depth) ASC, mv_name) as row_num
    FROM dep_tree
    GROUP BY mv_name
    ORDER BY MIN(depth) ASC, mv_name;

    -- Get total count for progress tracking
    SELECT COUNT(*) INTO total_views FROM ordered_mvs;

    RAISE NOTICE '';
    RAISE NOTICE '====== MATERIALIZED VIEW REFRESH STARTING ======';
    RAISE NOTICE 'Total views to refresh: %', total_views;
    RAISE NOTICE 'Schemas included: uk, xi, public';
    RAISE NOTICE 'Dependency detection method: Text analysis of view definitions';
    RAISE NOTICE 'Dependency-ordered refresh started at: %', to_char(overall_start, 'YYYY-MM-DD HH24:MI:SS');
    RAISE NOTICE '=================================================';
    RAISE NOTICE '';

    -- Loop over the ordered views and refresh each one.
    FOR current_mv, current_view_num IN
        SELECT mv_name, row_num FROM ordered_mvs ORDER BY row_num
    LOOP
        -- Get estimated size info before refresh
        BEGIN
            SELECT pg_total_relation_size(current_mv::regclass)
            INTO before_bytes;
        EXCEPTION WHEN others THEN
            before_bytes := NULL;
        END;

        RAISE NOTICE '[%/%] Starting refresh of % (%) at %',
            current_view_num, total_views, current_mv, COALESCE(pg_size_pretty(before_bytes), 'unknown size'),
            to_char(clock_timestamp(), 'HH24:MI:SS');

        retry_count := 0;
        total_elapsed := 0;
        after_bytes := NULL;  -- Initialize to NULL for failures
        LOOP
            start_time := clock_timestamp();
            BEGIN
                -- Set timeouts for this refresh (60s); covers both execution and lock waits
                PERFORM set_config('statement_timeout', '60s', true);
                PERFORM set_config('lock_timeout', '60s', true);

                -- Perform the refresh.
                EXECUTE 'REFRESH MATERIALIZED VIEW ' || current_mv || ' WITH DATA';

                -- Reset timeouts after success
                PERFORM set_config('statement_timeout', '0', true);
                PERFORM set_config('lock_timeout', '0', true);

                -- Get size after successful refresh
                BEGIN
                    SELECT pg_total_relation_size(current_mv::regclass)
                    INTO after_bytes;
                EXCEPTION WHEN others THEN
                    after_bytes := NULL;
                END;

                duration := clock_timestamp() - start_time;
                total_elapsed := total_elapsed + extract(epoch FROM duration);
                formatted_duration := round(extract(epoch FROM duration)::numeric, 3)::text || ' seconds';
                success_count := success_count + 1;

                RAISE NOTICE '[%/%] Completed % (size: % -> %) in %',
                    current_view_num, total_views, current_mv,
                    COALESCE(pg_size_pretty(before_bytes), 'unknown'),
                    COALESCE(pg_size_pretty(after_bytes), 'unknown'),
                    formatted_duration;

                EXIT;  -- Success, exit retry loop

            EXCEPTION
                WHEN query_canceled OR lock_not_available THEN  -- Covers statement_timeout (57014) and lock_timeout (55P03)
                    -- Reset timeouts to avoid affecting sleep or logs
                    PERFORM set_config('statement_timeout', '0', true);
                    PERFORM set_config('lock_timeout', '0', true);

                    duration := clock_timestamp() - start_time;
                    total_elapsed := total_elapsed + extract(epoch FROM duration);
                    formatted_duration := round(extract(epoch FROM duration)::numeric, 3)::text || ' seconds';

                    retry_count := retry_count + 1;
                    IF retry_count >= max_retries THEN
                        failure_count := failure_count + 1;
                        failed_views := array_append(failed_views, current_mv);
                        RAISE NOTICE '[%/%] Failed % after % retries: Timeout after %',
                            current_view_num, total_views, current_mv, max_retries, formatted_duration;
                        EXIT;  -- Max retries reached, move to next view
                    ELSE
                        backoff_seconds := 10 * (2 ^ (retry_count - 1));  -- Exponential: 10s, 20s, 40s...
                        RAISE NOTICE '[%/%] Timeout on % (attempt %/% after %); backing off %s and retrying',
                            current_view_num, total_views, current_mv, retry_count, max_retries, formatted_duration, backoff_seconds;
                        PERFORM pg_sleep(backoff_seconds);
                    END IF;

                WHEN OTHERS THEN  -- Other errors (e.g., syntax)
                    -- Reset timeouts
                    PERFORM set_config('statement_timeout', '0', true);
                    PERFORM set_config('lock_timeout', '0', true);

                    duration := clock_timestamp() - start_time;
                    total_elapsed := total_elapsed + extract(epoch FROM duration);
                    formatted_duration := round(extract(epoch FROM duration)::numeric, 3)::text || ' seconds';
                    failure_count := failure_count + 1;
                    failed_views := array_append(failed_views, current_mv);

                    RAISE NOTICE '[%/%] Failed %: % (in %)',
                        current_view_num, total_views, current_mv, SQLERRM, formatted_duration;
                    EXIT;  -- Non-timeout error, no retry, move to next
            END;
        END LOOP;

        -- Log to summary table after each view
        INSERT INTO refresh_summary (mv_name, retries, before_bytes, after_bytes, elapsed_seconds, status)
        VALUES (current_mv, retry_count, before_bytes, after_bytes, total_elapsed,
                CASE WHEN after_bytes IS NOT NULL THEN 'Success' ELSE 'Failure' END);

    END LOOP;

    -- Final summary with comprehensive statistics
    duration := clock_timestamp() - overall_start;
    formatted_duration := round(extract(epoch FROM duration)::numeric, 3)::text || ' seconds';

    RAISE NOTICE '';
    RAISE NOTICE '====== MATERIALIZED VIEW REFRESH SUMMARY ======';
    RAISE NOTICE 'Total runtime: %', formatted_duration;
    RAISE NOTICE 'Successfully refreshed: % views', success_count;
    RAISE NOTICE 'Failed refreshes: % views', failure_count;
    RAISE NOTICE 'Success rate: %', round((success_count::numeric / total_views * 100), 1) || '%';

    IF failure_count > 0 THEN
        RAISE NOTICE 'Failed views: %', array_to_string(failed_views, ', ');
        RAISE WARNING 'Some materialized views failed to refresh. Check logs above for details.';
    ELSE
        RAISE NOTICE 'All materialized views refreshed successfully!';
    END IF;

    RAISE NOTICE '';
    RAISE NOTICE '====== DEPENDENCY ANALYSIS ======';

    -- Debug: Show what dependencies are found by parsing view definitions
    RAISE NOTICE 'Dependencies found by parsing view definitions:';
    FOR current_mv IN
        SELECT dependent.schemaname || '.' || dependent.matviewname || ' likely depends on ' ||
               referenced.schemaname || '.' || referenced.matviewname as dep_info
        FROM pg_matviews dependent
        JOIN pg_matviews referenced ON referenced.schemaname IN ('uk', 'xi', 'public')
            AND dependent.schemaname IN ('uk', 'xi', 'public')
            AND dependent.matviewname != referenced.matviewname
        WHERE (
            dependent.definition ILIKE '%' || referenced.schemaname || '.' || referenced.matviewname || '%'
            OR dependent.definition ILIKE '%' || referenced.matviewname || '%'
        )
        ORDER BY dependent.schemaname, dependent.matviewname
        LIMIT 10  -- Show first 10 to avoid too much output
    LOOP
        RAISE NOTICE '  %', current_mv;
    END LOOP;

    -- Show the actual depth distribution
    RAISE NOTICE '';
    RAISE NOTICE 'Refresh order by dependency depth:';
    FOR current_mv IN
        SELECT 'Depth ' || depth || ': ' || COUNT(*) || ' views (' ||
               string_agg(mv_name, ', ' ORDER BY mv_name) || ')' as depth_info
        FROM ordered_mvs
        GROUP BY depth
        ORDER BY depth
    LOOP
        RAISE NOTICE '  %', current_mv;
    END LOOP;

    RAISE NOTICE '===============================================';

    -- Summary table: All retried/failed + top 10 largest by after size
    RAISE NOTICE '';
    RAISE NOTICE '====== REFRESH SUMMARY TABLE (Top 10 largest + all retried/failed) ======';
    RAISE NOTICE 'MV Name                  | Retries | Before Size | After Size | Elapsed Time | Status';
    RAISE NOTICE '-------------------------|---------|-------------|------------|--------------|--------';

    FOR rec IN
        WITH ranked AS (
            SELECT rs.*,
                   ROW_NUMBER() OVER (ORDER BY rs.after_bytes DESC NULLS LAST) AS rn
            FROM refresh_summary rs
            WHERE rs.status = 'Success'
        ),
        selected AS (
            SELECT rs2.mv_name, rs2.retries, rs2.before_bytes, rs2.after_bytes, rs2.elapsed_seconds, rs2.status
            FROM refresh_summary rs2
            WHERE rs2.retries > 0 OR rs2.status = 'Failure'
            UNION
            SELECT r.mv_name, r.retries, r.before_bytes, r.after_bytes, r.elapsed_seconds, r.status
            FROM ranked r
            WHERE r.rn <= 10
        )
        SELECT s.mv_name, s.retries,
               COALESCE(pg_size_pretty(s.before_bytes), 'unknown') AS before_size,
               COALESCE(pg_size_pretty(s.after_bytes), 'N/A') AS after_size,
               round(s.elapsed_seconds::numeric, 3)::text || 's' AS elapsed_time,
               s.status
        FROM selected s
        ORDER BY COALESCE(s.after_bytes, 0) DESC
    LOOP
        RAISE NOTICE '% | % | % | % | % | %',
            rpad(rec.mv_name, 24),
            lpad(rec.retries::text, 7),
            rpad(rec.before_size, 11),
            rpad(rec.after_size, 10),
            rpad(rec.elapsed_time, 12),
            rec.status;
    END LOOP;

    RAISE NOTICE '==================================================================================';
END $$;
