Sequel.migration do
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked
  up do
    if TradeTariffBackend.uk?
      Sequel::Model.db[:goods_nomenclatures_oplog]
        .where(goods_nomenclature_sid: [106_651, 107_908],
               validity_end_date: nil)
        .update(validity_end_date: '2022-12-31 23:59:59')
    end
  end

  down do
    if TradeTariffBackend.uk?
      Sequel::Model.db[:goods_nomenclatures_oplog]
        .where(goods_nomenclature_sid: [106_651, 107_908],
               validity_end_date: '2022-12-31 23:59:59')
        .update(validity_end_date: nil)
    end
  end
end
