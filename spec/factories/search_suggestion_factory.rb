FactoryBot.define do
  factory :search_suggestion do
    id { 'test' }
    value { 'test' }

    trait :search_reference do
      type { 'search_reference' }
      priority { 1 }
    end

    trait :goods_nomenclature do
      type { 'goods_nomenclature' }
      priority { 2 }
    end

    trait :full_chemical_name do
      type { 'full_chemical_name' }
      priority { 3 }
    end

    trait :full_chemical_cus do
      type { 'full_chemical_cus' }
      priority { 3 }
    end

    trait :full_chemical_cas do
      type { 'full_chemical_cas' }
      priority { 4 }
    end
  end
end
