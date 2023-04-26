FactoryBot.define do
  factory :search_suggestion do
    transient do
      goods_nomenclature { nil }
    end

    id { 'test' }
    value { 'test' }
    goods_nomenclature_sid { goods_nomenclature&.goods_nomenclature_sid || 124_456_789 }
    goods_nomenclature_class { goods_nomenclature&.ns_goods_nomenclature_class || 'Heading' }
    type { nil }

    trait :search_reference do
      type { 'search_reference' }
    end

    trait :goods_nomenclature do
      type { 'goods_nomenclature' }
    end

    trait :full_chemical_name do
      type { 'full_chemical_name' }
    end

    trait :full_chemical_cus do
      type { 'full_chemical_cus' }
    end

    trait :full_chemical_cas do
      type { 'full_chemical_cas' }
    end

    initialize_with do
      SearchSuggestion.unrestrict_primary_key
      SearchSuggestion.build(attributes)
    end
  end
end
