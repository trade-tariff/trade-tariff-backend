Sequel.migration do
  # IMPORTANT! Data migrations should be Idempotent, they may get re-run as part
  # of data rollbacks

  up do
    if TradeTariffBackend.uk?
      Sequel::Model.db[:goods_nomenclature_descriptions_oplog]
        .where(
          goods_nomenclature_description_period_sid: 157_681,
          goods_nomenclature_sid: 106_141,
          language_id: 'EN',
          goods_nomenclature_item_id: '3911909963',
          productline_suffix: '80',
          operation_date: '2022-09-07',
          filename: 'tariff_dailyExtract_v1_20220907T235959.gzip',
          description: nil,
        )
        .update(
          description: 'Mixture, containing by weight:
-	20% or more but not more than 40% of a copolymer of methyl vinyl ether and monobutyl maleate (CAS RN 25119-68-0),
-	7% or more but not more than 20% of a copolymer of methyl vinyl ether and monoethyl maleate (CAS RN 25087-06-3),
-	40% or more, but not more than 65% of ethanol (CAS RN 64-17-5),
-	1% or more but not more than 7% of butan-1-ol (CAS RN 71-36-3)',
        )
    end
  end

  down do
    if TradeTariffBackend.uk?
      Sequel::Model.db[:goods_nomenclature_descriptions_oplog]
        .where(
          goods_nomenclature_description_period_sid: 157_681,
          goods_nomenclature_sid: 106_141,
          language_id: 'EN',
          goods_nomenclature_item_id: '3911909963',
          productline_suffix: '80',
          operation_date: '2022-09-07',
          filename: 'tariff_dailyExtract_v1_20220907T235959.gzip',
          description: 'Mixture, containing by weight:
-	20% or more but not more than 40% of a copolymer of methyl vinyl ether and monobutyl maleate (CAS RN 25119-68-0),
-	7% or more but not more than 20% of a copolymer of methyl vinyl ether and monoethyl maleate (CAS RN 25087-06-3),
-	40% or more, but not more than 65% of ethanol (CAS RN 64-17-5),
-	1% or more but not more than 7% of butan-1-ol (CAS RN 71-36-3)',
        )
        .update(
          description: nil,
        )
    end
  end
end
