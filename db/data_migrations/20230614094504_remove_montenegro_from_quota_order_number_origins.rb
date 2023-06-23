Sequel.migration do
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked

  up do
    if TradeTariffBackend.uk?
      QuotaOrderNumberOrigin::Operation.where(
        quota_order_number_sid: 20_919,
        quota_order_number_origin_sid: 20_988,
        geographical_area_id: 'ME',
        operation_date: nil,
        operation: 'C',
        geographical_area_sid: 348,
        filename: nil,
      ).delete
    end
  end

  down do
    if TradeTariffBackend.uk?
      QuotaOrderNumberOrigin.unrestrict_primary_key

      QuotaOrderNumberOrigin.create(
        quota_order_number_sid: 20_919,
        quota_order_number_origin_sid: 20_988,
        geographical_area_id: 'ME',
        operation_date: nil,
        operation: 'C',
        geographical_area_sid: 348,
        filename: nil,
        validity_start_date: Date.parse('2021-01-01T00:00:00.000Z'),
      )

      QuotaOrderNumberOrigin.restrict_primary_key
    end
  end
end
