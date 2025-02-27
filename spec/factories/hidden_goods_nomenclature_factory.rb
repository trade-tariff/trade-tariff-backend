FactoryBot.define do
  factory :hidden_goods_nomenclature do
    goods_nomenclature_item_id { Array.new(10) { Random.rand(9) }.join }

    trait :chapter do
      goods_nomenclature_item_id { "#{Array.new(2) { Random.rand(9) }.join}00000000" }
    end

    trait :heading do
      goods_nomenclature_item_id { "#{Array.new(4) { Random.rand(1..8) }.join}000000" }
    end
  end
end
