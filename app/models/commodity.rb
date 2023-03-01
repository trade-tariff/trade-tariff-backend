class Commodity < GoodsNomenclature
  include TenDigitGoodsNomenclature
  include SearchReferenceable
  prepend GoodsNomenclatures::Overrides::Commodity if TradeTariffBackend.use_nested_set?

  plugin :elasticsearch
end
