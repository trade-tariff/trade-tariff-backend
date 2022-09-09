Sequel.migration do
  # IMPORTANT! Data migrations should be Idempotent, they may get re-run as part
  # of data rollbacks

  up do
    if TradeTariffBackend.uk?
      Sequel::Model.db[:goods_nomenclature_descriptions_oplog]
        .where(
          goods_nomenclature_description_period_sid: 155_818,
          goods_nomenclature_sid: 107_510,
          language_id: 'EN',
          goods_nomenclature_item_id: '4421200000',
          productline_suffix: '80',
          operation_date: '2021-12-23',
          filename: 'tariff_dailyExtract_v1_20220816T235959.gzip',
          description: nil,
        )
        .update(
          description: 'Coffins',
        )
    end
  end

  down do
    if TradeTariffBackend.uk?
      Sequel::Model.db[:goods_nomenclature_descriptions_oplog]
        .where(
          goods_nomenclature_description_period_sid: 155_818,
          goods_nomenclature_sid: 107_510,
          language_id: 'EN',
          goods_nomenclature_item_id: '4421200000',
          productline_suffix: '80',
          operation_date: '2021-12-23',
          filename: 'tariff_dailyExtract_v1_20220816T235959.gzip',
          description: 'Coffins',
        )
        .update(
          description: nil,
        )
    end
  end
end
