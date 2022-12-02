Sequel.migration do
  # IMPORTANT! Data migrations should be Idempotent, they may get re-run as part
  # of data rollbacks

  up do
    if TradeTariffBackend.uk?
      HiddenGoodsNomenclature.unrestrict_primary_key

      GoodsNomenclature.where(Sequel.like(:goods_nomenclature_item_id, '98%')).where(validity_end_date: nil).all.each do |goods_nomenclature|
        HiddenGoodsNomenclature.find_or_create(goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id)
      end

      HiddenGoodsNomenclature.restrict_primary_key
    end
  end

  down do
    if TradeTariffBackend.uk?
      item_ids = GoodsNomenclature.where(Sequel.like(:goods_nomenclature_item_id, '98%')).where(validity_end_date: nil).all.pluck(:goods_nomenclature_item_id)
      HiddenGoodsNomenclature.where(goods_nomenclature_item_id: item_ids).delete
    end
  end
end
