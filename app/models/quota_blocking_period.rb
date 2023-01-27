class QuotaBlockingPeriod < Sequel::Model
  plugin :oplog, primary_key: :quota_blocking_period_sid

  plugin :time_machine, period_start_column: :blocking_start_date, period_end_column: :blocking_end_date

  set_primary_key [:quota_blocking_period_sid]
end
