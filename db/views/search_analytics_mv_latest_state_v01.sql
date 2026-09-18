CREATE FUNCTION search_analytics_mv_latest_state(a bigint, b bigint) RETURNS bigint
LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE AS $$
  SELECT CASE WHEN (a >> 2) = (b >> 2) THEN a | b ELSE greatest(a, b) END
$$;

CREATE AGGREGATE search_analytics_mv_latest_state(bigint) (
  SFUNC = search_analytics_mv_latest_state,
  STYPE = bigint,
  COMBINEFUNC = search_analytics_mv_latest_state,
  PARALLEL = SAFE
);
