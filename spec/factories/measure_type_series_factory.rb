FactoryBot.define do
  factory :measure_type_series do
    measure_type_series_id   { generate(:measure_type_series_id) }
    validity_start_date      { 3.years.ago.beginning_of_day }
    validity_end_date        { nil }

    trait :xml do
      measure_type_combination { 0 }
      validity_end_date        { 1.year.ago.beginning_of_day }
    end
  end

  factory :measure_type_series_description do
    measure_type_series_id { generate(:measure_type_series_id) }
    description { Forgery(:basic).text }

    trait :xml do
      language_id { 'EN' }
    end
  end
end
