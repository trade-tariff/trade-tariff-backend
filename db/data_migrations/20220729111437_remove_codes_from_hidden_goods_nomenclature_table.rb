Sequel.migration do
  if TradeTariffBackend.uk?
    codes = %w[9900000000 9905000000 9919000000 9919000010 9919000020]

    up do
      codes.each do |code|
        HiddenGoodsNomenclature.where(goods_nomenclature_item_id: code).delete
      end
    end

    down do
      codes.each do |code|
        next unless HiddenGoodsNomenclature.where(goods_nomenclature_item_id: code).count.zero?

        HiddenGoodsNomenclature.unrestrict_primary_key
        HiddenGoodsNomenclature.create(goods_nomenclature_item_id: code)
        HiddenGoodsNomenclature.restrict_primary_key
      end
    end
  end
end
