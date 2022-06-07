FactoryBot.define do
  sequence(:sid) { |n| n }

  factory :search_reference do
    title { Forgery(:basic).text }
    referenced { create :heading }

    trait :with_current_commodity do
      referenced { create :commodity, validity_end_date: Time.zone.tomorrow }
    end

    trait :with_non_current_commodity do
      referenced { create :commodity, validity_end_date: Time.zone.yesterday }
    end
  end
end
