Sequel.migration do
  if TradeTariffBackend.uk?
    codes = %w[9900000000 9905000000 9919000000 9919000010 9919000020]

    up do
      codes.each do |goods_nomenclature_item_id|
        HiddenGoodsNomenclature.where(goods_nomenclature_item_id:).delete
      end
    end

    down do
      HiddenGoodsNomenclature.unrestrict_primary_key

      codes.each do |goods_nomenclature_item_id|
        next unless HiddenGoodsNomenclature.where(goods_nomenclature_item_id:).count.zero?

        HiddenGoodsNomenclature.create(goods_nomenclature_item_id:)
      end

      HiddenGoodsNomenclature.restrict_primary_key
    end
  end
end
