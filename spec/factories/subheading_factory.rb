FactoryBot.define do
  factory :subheading, parent: :commodity, class: 'Subheading' do
    non_declarable

    trait :with_commodities do
      after(:create) do |subheading, _evaluator|
        create(:commodity, :with_description, parent: subheading)
      end
    end
  end
end
