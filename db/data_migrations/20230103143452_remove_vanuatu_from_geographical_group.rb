Sequel.migration do
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked

  up do
    if TradeTariffBackend.uk?
      Sequel::Model.db[:geographical_area_memberships_oplog]
        .where(
          geographical_area_group_sid: 504,
          geographical_area_sid: 107,
          operation_date: '2022-06-22',
          operation: 'C',
        ).delete
    end
  end

  down do
    # deletion, cannot be reversed
  end
end
