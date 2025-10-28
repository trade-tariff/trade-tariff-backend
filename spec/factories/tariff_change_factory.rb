FactoryBot.define do
  factory :tariff_change do
    sequence(:object_sid) { |n| n }
    sequence(:goods_nomenclature_sid) { |n| n }
    goods_nomenclature_item_id { goods_nomenclature_sid ? sprintf('%010d', goods_nomenclature_sid) : '0000000001' }
    type { 'Commodity' }
    action { 'creation' }
    operation_date { Date.current }
    date_of_effect { Time.zone.now.to_date }
    validity_start_date { Time.zone.now }

    trait :update do
      action { 'update' }
    end

    trait :deletion do
      action { 'deletion' }
    end

    trait :commodity_description do
      type { 'CommodityDescription' }
    end

    trait :measure do
      type { 'Measure' }
    end
  end
end
