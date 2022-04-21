TradeTariffBackend::DataMigrator.migration do
  name "Populates HiddenGoodsNomenclature with data"
  desc "Certain GoodsNomenclatures should be hidden in UK Tariff."

  CODES =
    ["9900000000",
     "9905000000",
     "9919000000",
     "9930000000",
     "9930240000",
     "9930270000",
     "9930990000",
     "9931000000",
     "9931240000",
     "9931270000",
     "9931990000",
     "9950000000"]

  up do
    applicable {
      HiddenGoodsNomenclature.where(goods_nomenclature_item_id: CODES).count != CODES.size
      false
    }

    apply {
      # for idempotency
      HiddenGoodsNomenclature.where(goods_nomenclature_item_id: CODES)
                             .delete

      CODES.each do |code|
        unless HiddenGoodsNomenclature.where(goods_nomenclature_item_id: code).present?
          HiddenGoodsNomenclature.new { |hidden_gono|
            hidden_gono.goods_nomenclature_item_id = code
          }.save
        end
      end
    }
  end

  down do
    applicable {
      HiddenGoodsNomenclature.where(goods_nomenclature_item_id: CODES).any?
      false
    }

    apply {
      HiddenGoodsNomenclature.where(goods_nomenclature_item_id: CODES)
                             .delete
    }
  end
end
