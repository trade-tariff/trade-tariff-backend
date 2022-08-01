Sequel.migration do
  if TradeTariffBackend.uk?
    codes = %w[9919000030 9919000040 9919000050 9919000060 9930000000 9930240000 9930270000 9930990000 9931000000 9931240000 9931270000 9931990000 9950000000]

    up do
      HiddenGoodsNomenclature.unrestrict_primary_key

      codes.each do |goods_nomenclature_item_id|
        next unless HiddenGoodsNomenclature.where(goods_nomenclature_item_id:).count.zero?

        HiddenGoodsNomenclature.create(goods_nomenclature_item_id:)
      end

      HiddenGoodsNomenclature.restrict_primary_key
    end

    down do
      codes.each do |goods_nomenclature_item_id|
        HiddenGoodsNomenclature.where(goods_nomenclature_item_id:).delete
      end
    end
  end
end
