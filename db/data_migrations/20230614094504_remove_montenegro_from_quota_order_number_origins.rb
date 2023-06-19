Sequel.migration do
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked

  up do
    if TradeTariffBackend.uk?
      Sequel::Model.db[:quota_order_number_origins_oplog].where(quota_order_number_sid: 20919, quota_order_number_origin_sid: 20988, geographical_area_id: "ME", operation_date: nil, oid: 8674, operation: "C", geographical_area_sid: 348).delete
    end
  end

  down do
    # deletion, cannot be reversed
  end
end
