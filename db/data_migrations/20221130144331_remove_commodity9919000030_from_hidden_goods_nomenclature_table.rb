Sequel.migration do
  # IMPORTANT! Data migrations should be Idempotent, they may get re-run as part
  # of data rollbacks
  up do
    HiddenGoodsNomenclature.where(goods_nomenclature_item_id: '9919000030').delete if TradeTariffBackend.uk?
  end

  down do
    if TradeTariffBackend.uk?
      HiddenGoodsNomenclature.unrestrict_primary_key

      HiddenGoodsNomenclature.find_or_create(goods_nomenclature_item_id: '9919000030')

      HiddenGoodsNomenclature.restrict_primary_key
    end
  end
end
