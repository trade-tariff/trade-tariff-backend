Sequel.migration do
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked
  up do
    if TradeTariffBackend.uk?
      HiddenGoodsNomenclature.where(goods_nomenclature_item_id: /^98/).delete
    end
  end

  down do
    if TradeTariffBackend.uk?
      ids = GoodsNomenclature
        .where(goods_nomenclature_item_id: /^98/)
        .select_map(:goods_nomenclature_item_id)

      HiddenGoodsNomenclature.unrestrict_primary_key
      ids.map do |goods_nomenclature_item_id|
        HiddenGoodsNomenclature.new(goods_nomenclature_item_id:).save
      end
      HiddenGoodsNomenclature.restrict_primary_key
    end
  end
end
