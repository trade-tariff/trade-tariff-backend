Sequel.migration do
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked

  up do
    should_import = !Sequel::Model.db[:quota_order_number_origin_exclusions_oplog]
                                  .exclude(filename: nil)
                                  .exclude(operation_date: Date.parse('2023-01-16')..)
                                  .first

    if TradeTariffBackend.uk? && should_import
      run Rails.root
               .join('db/data_migrations/sql')
               .join('20230116112708_quota_order_number_origin_exclusion_backfill.sql')
               .read
    end
  end

  down do
    if TradeTariffBackend.uk?
      Sequel::Model.db[:quota_order_number_origin_exclusions_oplog]
                   .exclude(filename: nil)
                   .exclude(operation_date: Date.parse('2023-01-16')..)
                   .delete
    end
  end
end
