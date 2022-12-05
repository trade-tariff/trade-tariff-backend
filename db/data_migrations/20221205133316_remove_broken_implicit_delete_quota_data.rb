Sequel.migration do
  # IMPORTANT! Data migrations should be Idempotent, they may get re-run as part
  # of data rollbacks

  up do
    if TradeTariffBackend.uk?
      origin = QuotaOrderNumberOrigin::Operation.new

      origin.quota_order_number_origin_sid = 21_096
      origin.quota_order_number_sid = 20_142
      origin.geographical_area_id = 'IN'
      origin.validity_start_date = '2021-01-01T00:00:00'
      origin.validity_end_date = nil
      origin.geographical_area_sid = '154'
      origin.operation = Sequel::Plugins::Oplog::DESTROY_OPERATION
      origin.operation_date = '2022-12-03'
      origin.filename = 'tariff_dailyExtract_v1_20221202T235959.gzip'

      origin.save
    end
  end

  down do
    if TradeTariffBackend.uk?
      QuotaOrderNumberOrigin::Operation.find(
        quota_order_number_origin_sid: 21_096,
        operation: Sequel::Plugins::Oplog::DESTROY_OPERATION,
        filename: 'tariff_dailyExtract_v1_20221202T235959.gzip',
      ).delete
    end
  end
end
