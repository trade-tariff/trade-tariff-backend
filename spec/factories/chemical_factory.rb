FactoryBot.define do
  sequence(:cas) { |n| "0-#{n}-0" }

  factory :chemical do
    cas { generate(:cas) }
    sequence(:id) { |n| n }

    trait :with_name do
      after(:create) do |chemical, _evaluator|
        create(:chemical_name, chemical_id: chemical.id)
      end
    end
  end

  factory :chemical_name do
    chemical

    name { Forgery(:basic).text }
  end

  factory :chemicals_goods_nomenclatures do
    chemical_id { Forgery(:basic).number }
    goods_nomenclature_sid { Forgery(:basic).number }
  end
end
