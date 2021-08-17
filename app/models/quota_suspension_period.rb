class QuotaSuspensionPeriod < Sequel::Model
  plugin :time_machine, period_start_column: :suspension_start_date,
                        period_end_column: :suspension_end_date
  plugin :oplog, primary_key: :quota_suspension_period_sid

  set_primary_key [:quota_suspension_period_sid]
end
