FactoryBot.define do
  factory :search_suggestion do
    transient do
      goods_nomenclature { nil }
    end

    id { goods_nomenclature&.goods_nomenclature_sid || generate(:sid) }
    value { goods_nomenclature&.short_code || 'test' }
    goods_nomenclature_sid { goods_nomenclature&.goods_nomenclature_sid || 124_456_789 }
    goods_nomenclature_class { goods_nomenclature&.goods_nomenclature_class || 'Heading' }
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

    trait :known_brand do
      type { 'known_brand' }
      value { 'Samsung' }
    end

    trait :colloquial_term do
      type { 'colloquial_term' }
      value { 'laptop' }
    end

    trait :synonym do
      type { 'synonym' }
      value { 'portable computer' }
    end

    trait :with_search_reference do
      before(:create) do |search_suggestion, _evaluator|
        if search_suggestion.type == 'search_reference'
          create(
            :search_reference,
            referenced: search_suggestion.goods_nomenclature,
            title: search_suggestion.value,
          )
        end
      end
    end

    initialize_with do
      SearchSuggestion.unrestrict_primary_key
      SearchSuggestion.build(attributes)
    end
  end
end
