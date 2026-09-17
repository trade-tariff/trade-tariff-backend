# frozen_string_literal: true

Sequel.migration do # rubocop:disable Metrics/BlockLength
  up do # rubocop:disable Metrics/BlockLength
    run <<~SQL
      CREATE FUNCTION search_analytics_latest_state(a bigint, b bigint) RETURNS bigint
      LANGUAGE sql IMMUTABLE STRICT PARALLEL SAFE AS $$
        SELECT CASE WHEN (a >> 2) = (b >> 2) THEN a | b ELSE greatest(a, b) END
      $$;
      CREATE AGGREGATE search_analytics_latest_state(bigint) (
        SFUNC = search_analytics_latest_state,
        STYPE = bigint,
        COMBINEFUNC = search_analytics_latest_state,
        PARALLEL = SAFE
      );
    SQL

    create_table :search_analytics_read_models do # rubocop:disable Rails/CreateTableWithTimestamps
      primary_key :id
      String :service, null: false
      String :region, null: false
      Integer :version, null: false
      column :fingerprints, :jsonb, null: false
      column :source_versions, :jsonb, null: false
      DateTime :built_at, null: false
      index %i[service region built_at], name: :idx_search_analytics_read_models_latest
    end

    create_table :search_analytics_journey_days do # rubocop:disable Rails/CreateTableWithTimestamps
      foreign_key :read_model_id, :search_analytics_read_models, null: false, on_delete: :cascade
      Date :reporting_date, null: false
      column :journey_key, :bytea, null: false
      Bignum :all_hours, null: false
      Bignum :classic_hours, null: false
      Bignum :internal_hours, null: false
      Bignum :terminal
      Integer :flags, null: false
      index %i[read_model_id journey_key reporting_date], unique: true, name: :idx_search_analytics_journey_days_identity
      index %i[read_model_id reporting_date], name: :idx_search_analytics_journey_days_date
    end

    create_table :search_analytics_journey_rollups do # rubocop:disable Rails/CreateTableWithTimestamps
      foreign_key :read_model_id, :search_analytics_read_models, null: false, on_delete: :cascade
      Date :reporting_date, null: false
      String :view, null: false
      String :bucket_size, null: false
      DateTime :bucket, null: false
      Bignum :journeys, null: false
      Bignum :completed, null: false
      Bignum :failed, null: false
      Bignum :nonterminal, null: false
      Bignum :unknown, null: false
      Bignum :selected, null: false
      Bignum :zero_result, null: false
      index %i[read_model_id reporting_date view bucket_size bucket], unique: true, name: :idx_search_analytics_journey_rollups_identity
    end

    create_table :search_analytics_multi_day_observations do # rubocop:disable Rails/CreateTableWithTimestamps
      foreign_key :read_model_id, :search_analytics_read_models, null: false, on_delete: :cascade
      Date :reporting_date, null: false
      column :journey_key, :bytea, null: false
      Bignum :all_hours, null: false
      Bignum :classic_hours, null: false
      Bignum :internal_hours, null: false
      Bignum :terminal
      Integer :flags, null: false
      index %i[read_model_id journey_key reporting_date], unique: true, name: :idx_search_analytics_multi_day_identity
      index %i[read_model_id reporting_date], name: :idx_search_analytics_multi_day_date
    end
  end

  down do
    drop_table :search_analytics_multi_day_observations
    drop_table :search_analytics_journey_rollups
    drop_table :search_analytics_journey_days
    drop_table :search_analytics_read_models
    run <<~SQL
      DROP AGGREGATE IF EXISTS search_analytics_latest_state(bigint);
      DROP FUNCTION IF EXISTS search_analytics_latest_state(bigint, bigint);
    SQL
  end
end
