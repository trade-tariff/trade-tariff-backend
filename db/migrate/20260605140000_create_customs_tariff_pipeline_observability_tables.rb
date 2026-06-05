Sequel.migration do
  up do
    create_table :customs_tariff_pipeline_events do
      primary_key :id
      String :event_type, size: 40, null: false
      String :outcome, size: 20, null: false
      String :customs_tariff_update_version
      String :subject_type, size: 80
      String :subject_id, size: 80
      String :whodunnit
      DateTime :occurred_at, null: false
      Integer :duration_ms
      Integer :records_total
      Integer :records_succeeded
      Integer :records_failed
      Integer :records_pending
      String :error_code, size: 80
      String :error_message, text: true
      column :metadata, :jsonb, null: false, default: Sequel.lit("'{}'::jsonb")
      DateTime :created_at, null: false, default: Sequel.lit('CURRENT_TIMESTAMP')

      index :occurred_at
      index %i[event_type outcome occurred_at]
      index %i[outcome occurred_at]
      index %i[customs_tariff_update_version occurred_at]
      index %i[subject_type subject_id]
    end

    alter_table :customs_tariff_pipeline_events do
      add_constraint :customs_tariff_pipeline_events_duration_non_negative,
                     Sequel.lit('duration_ms IS NULL OR duration_ms >= 0')
      add_constraint :customs_tariff_pipeline_events_counts_non_negative,
                     Sequel.lit(
                       <<~SQL.squish,
                         (records_total IS NULL OR records_total >= 0)
                         AND (records_succeeded IS NULL OR records_succeeded >= 0)
                         AND (records_failed IS NULL OR records_failed >= 0)
                         AND (records_pending IS NULL OR records_pending >= 0)
                       SQL
                     )
      add_constraint :customs_tariff_pipeline_events_metadata_object,
                     Sequel.lit("jsonb_typeof(metadata) = 'object'")
    end

    create_table :customs_tariff_pipeline_metric_bins do
      primary_key :id
      String :bucket_size, size: 10, null: false
      DateTime :bucket_start_at, null: false
      String :metric_name, size: 80, null: false
      String :customs_tariff_update_version, null: false, default: 'all'
      String :event_type, size: 40, null: false, default: 'all'
      String :outcome, size: 20, null: false, default: 'all'
      String :note_type, size: 40, null: false, default: 'all'
      Bignum :count, null: false, default: 0
      Bignum :value_sum
      Bignum :value_min
      Bignum :value_max
      Bignum :value_last
      column :metadata, :jsonb, null: false, default: Sequel.lit("'{}'::jsonb")
      DateTime :created_at, null: false, default: Sequel.lit('CURRENT_TIMESTAMP')
      DateTime :updated_at, null: false, default: Sequel.lit('CURRENT_TIMESTAMP')

      index %i[bucket_size bucket_start_at metric_name]
      index %i[metric_name bucket_size bucket_start_at]
      index %i[customs_tariff_update_version bucket_start_at]
      index %i[event_type outcome bucket_start_at]
      index %i[
        bucket_size
        bucket_start_at
        metric_name
        customs_tariff_update_version
        event_type
        outcome
        note_type
      ], unique: true, name: :customs_tariff_pipeline_metric_bins_unique_key
    end

    alter_table :customs_tariff_pipeline_metric_bins do
      add_constraint :customs_tariff_pipeline_metric_bins_bucket_size_valid,
                     Sequel.lit("bucket_size IN ('minute', 'hour', 'day')")
      add_constraint :customs_tariff_pipeline_metric_bins_count_non_negative,
                     Sequel.lit('count >= 0')
      add_constraint :customs_tariff_pipeline_metric_bins_metadata_object,
                     Sequel.lit("jsonb_typeof(metadata) = 'object'")
    end

    create_table :customs_tariff_pipeline_alerts do
      primary_key :id
      String :alert_type, size: 80, null: false
      String :severity, size: 20, null: false, default: 'warning'
      String :status, size: 20, null: false, default: 'open'
      String :customs_tariff_update_version
      String :metric_name, size: 80
      DateTime :bucket_start_at
      DateTime :triggered_at, null: false
      DateTime :acknowledged_at
      DateTime :resolved_at
      String :acknowledged_by
      String :resolved_by
      Bignum :threshold_value
      Bignum :observed_value
      String :message, text: true, null: false
      column :metadata, :jsonb, null: false, default: Sequel.lit("'{}'::jsonb")
      DateTime :created_at, null: false, default: Sequel.lit('CURRENT_TIMESTAMP')
      DateTime :updated_at, null: false, default: Sequel.lit('CURRENT_TIMESTAMP')

      index %i[status severity triggered_at]
      index %i[alert_type status triggered_at]
      index %i[customs_tariff_update_version triggered_at]
      index :triggered_at
    end

    alter_table :customs_tariff_pipeline_alerts do
      add_constraint :customs_tariff_pipeline_alerts_severity_valid,
                     Sequel.lit("severity IN ('info', 'warning', 'critical')")
      add_constraint :customs_tariff_pipeline_alerts_status_valid,
                     Sequel.lit("status IN ('open', 'acknowledged', 'resolved')")
      add_constraint :customs_tariff_pipeline_alerts_resolution_order_valid,
                     Sequel.lit('resolved_at IS NULL OR resolved_at >= triggered_at')
      add_constraint :customs_tariff_pipeline_alerts_acknowledgement_order_valid,
                     Sequel.lit('acknowledged_at IS NULL OR acknowledged_at >= triggered_at')
      add_constraint :customs_tariff_pipeline_alerts_metadata_object,
                     Sequel.lit("jsonb_typeof(metadata) = 'object'")
    end
  end

  down do
    drop_table :customs_tariff_pipeline_alerts
    drop_table :customs_tariff_pipeline_metric_bins
    drop_table :customs_tariff_pipeline_events
  end
end
