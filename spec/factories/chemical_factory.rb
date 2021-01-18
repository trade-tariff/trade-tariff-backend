FactoryBot.define do
  factory :chemical do
    cas { "0-#{Forgery(:basic).number}-0" }
    sequence(:id) { |n| n }

    trait :with_name do
      after(:create) do |chemical, _evaluator|
        FactoryBot.create(:chemical_name, chemical_id: chemical.id)
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
