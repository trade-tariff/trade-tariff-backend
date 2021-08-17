class QuotaBlockingPeriod < Sequel::Model
  plugin :time_machine, period_start_column: :blocking_start_date,
                        period_end_column: :blocking_end_date
  plugin :oplog, primary_key: :quota_definition_sid

  set_primary_key [:quota_blocking_period_sid]
end
