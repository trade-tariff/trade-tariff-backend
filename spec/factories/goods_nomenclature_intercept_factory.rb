FactoryBot.define do
  factory :goods_nomenclature_intercept do
    goods_nomenclature_sid { generate(:goods_nomenclature_sid) }
    message { 'Read the classification notes for this commodity.' }
    excluded { false }
  end
end
