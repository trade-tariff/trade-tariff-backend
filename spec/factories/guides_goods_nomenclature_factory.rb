FactoryBot.define do
  factory :guides_goods_nomenclature do
    transient do
      goods_nomenclature {}
      guide {}
    end

    goods_nomenclature_sid { goods_nomenclature&.goods_nomenclature_sid }
    guide_id { guide&.id }
  end
end
