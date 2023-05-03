Sequel.migration do
  balance_events = [
    {
      quota_definition_sid: 22_046,
      occurrence_timestamp: '2023-01-06T16:01:00.000Z',
      last_import_date_in_allocation: nil,
      old_balance: 998_000.0,
      new_balance: 1_471_000.0,
      imported_amount: 0.0,
      operation: 'C',
      operation_date: Date.parse('2023-01-09'),
      filename: 'tariff_dailyExtract_v1_20230109T235959.gzip',
    },
    {
      quota_definition_sid: 22_052,
      occurrence_timestamp: '2023-01-06T16:01:00.000Z',
      last_import_date_in_allocation: nil,
      old_balance: 998_000.0,
      new_balance: 1_471_000.0,
      imported_amount: 0.0,
      operation: 'C',
      operation_date: Date.parse('2023-01-09'),
      filename: 'tariff_dailyExtract_v1_20230109T235959.gzip',
    },
  ].freeze

  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked
  up do
    if TradeTariffBackend.uk?
      balance_events.each do |event_data|
        QuotaBalanceEvent.where(event_data).destroy
      end
    end
  end

  down do
    if TradeTariffBackend.uk?
      balance_events.each do |event_data|
        QuotaBalanceEvent.unrestrict_primary_key
        QuotaBalanceEvent.new(event_data).save
        QuotaBalanceEvent.restrict_primary_key
      end
    end
  end
end
