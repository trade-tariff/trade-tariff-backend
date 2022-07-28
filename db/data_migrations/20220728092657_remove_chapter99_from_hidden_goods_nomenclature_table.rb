Sequel.migration do
  up do
    HiddenGoodsNomenclature.where(goods_nomenclature_item_id: '9900000000').delete
  end

  down do
    if HiddenGoodsNomenclature.where(goods_nomenclature_item_id: '9900000000').count.zero?
      HiddenGoodsNomenclature.unrestrict_primary_key
      HiddenGoodsNomenclature.create(goods_nomenclature_item_id: '9900000000')
      HiddenGoodsNomenclature.restrict_primary_key
    end
  end
end
