Sequel.migration do
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked
  up do
    descriptions = GoodsNomenclatureDescription::Operation.where(
      goods_nomenclature_description_period_sid: 155_286,
      filename: [nil, 'tariff_dailyExtract_v1_20221004T235959.gzip', 'tariff_dailyExtract_v1_20211209T235959.gzip'], # Restricts rollbacks/reapplies from adjusting future changes to the descriptions for this period
    )

    descriptions
      .update(
        description: 'Punching, notching or nibbling machines (excluding presses) for flat products including combined punching and shearing machines',
      )
  end

  # Two of the four oplog entries have the correct description and the latest oid does not. One has a nil description. They should all just match the description above so there's nothing to revert
  down do
  end
end
