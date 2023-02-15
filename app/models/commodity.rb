class Commodity < GoodsNomenclature
  include TenDigitGoodsNomenclature
  include SearchReferenceable

  plugin :elasticsearch
end
