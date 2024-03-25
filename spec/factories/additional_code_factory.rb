FactoryBot.define do
  sequence(:additional_code_sid) { |n| n }
  sequence(:additional_code_description_period_sid) { |n| n }
  sequence(:additional_code_id) { |n| 'AAA'.tap { |ac| n.times { ac.next! } } }
  sequence(:meursing_additional_code_sid) { |n| n }

  factory :additional_code do
    additional_code_sid     { generate(:additional_code_sid) }
    additional_code_type_id { '1' }
    additional_code         { generate(:additional_code_id) }
    validity_start_date     { 2.years.ago.beginning_of_day }
    validity_end_date       { nil }

    trait :with_export_refund_nomenclature do
      after(:build) do |adco, _evaluator|
        create(:export_refund_nomenclature, export_refund_code: adco.additional_code)
      end
    end

    trait :with_description do
      transient do
        additional_code_description { Forgery('basic').text }
      end

      after(:build) do |adco, evaluator|
        create(:additional_code_description, :with_period, additional_code_sid: adco.additional_code_sid, description: evaluator.additional_code_description)
      end
    end

    trait :with_footnote_association do
      after(:build) do |additional_code, _evaluator|
        create(:footnote_association_additional_code, additional_code_sid: additional_code.additional_code_sid)
      end
    end
  end

  factory :additional_code_description_period do
    additional_code_description_period_sid { generate(:additional_code_description_period_sid) }
    additional_code_sid                    { generate(:additional_code_sid) }
    additional_code_type_id                { generate(:additional_code_type_id) }
    additional_code                        { Forgery(:basic).text(exactly: 3) }
    validity_start_date                    { 2.years.ago.beginning_of_day }
    validity_end_date                      { nil }
  end

  factory :additional_code_description do
    transient do
      valid_at { 2.years.ago.beginning_of_day }
      valid_to { nil }
    end

    additional_code_description_period_sid { generate(:additional_code_description_period_sid) }
    additional_code_sid                    { generate(:additional_code_sid) }
    additional_code_type_id                { generate(:additional_code_type_id) }
    additional_code                        { Forgery(:basic).text(exactly: 3) }
    description                            { "#{Forgery('basic').text} #{Forgery('basic').text} #{Forgery('basic').text}" }

    trait :with_period do
      after(:create) do |adco_description, evaluator|
        create(:additional_code_description_period, additional_code_description_period_sid: adco_description.additional_code_description_period_sid,
                                                    additional_code_sid: adco_description.additional_code_sid,
                                                    additional_code_type_id: adco_description.additional_code_type_id,
                                                    additional_code: adco_description.additional_code,
                                                    validity_start_date: evaluator.valid_at,
                                                    validity_end_date: evaluator.valid_to)
      end
    end
  end

  factory :additional_code_type do
    additional_code_type_id { generate(:additional_code_type_id) }
    application_code        { '1' }
    validity_start_date     { 2.years.ago.beginning_of_day }
    validity_end_date       { nil }

    trait :ern do
      application_code { '0' }
    end

    trait :adco do
      application_code { '1' }
    end

    trait :meursing do
      application_code { '3' }
    end

    trait :ern_agricultural do
      application_code { '4' }
    end

    trait :with_meursing_table_plan do
      meursing_table_plan_id { Forgery(:basic).number }

      after(:build) do |adco_type, _evaluator|
        create(:meursing_table_plan, meursing_table_plan_id: adco_type.meursing_table_plan_id)
      end
    end

    trait :with_measure_type do
      transient { measure_type_id { '468' } }

      after(:build) do |additional_code_type, evaluator|
        create(:additional_code_type_measure_type, additional_code_type_id: additional_code_type.additional_code_type_id, measure_type_id: evaluator.measure_type_id)
      end
    end

    trait :with_description do
      transient do
        language_id { 'EN' }
      end

      after(:create) do |additional_code_type, evaluator|
        create(:additional_code_type_description, additional_code_type_id: additional_code_type.additional_code_type_id, language_id: evaluator.language_id)
      end
    end

    trait :xml do
      validity_end_date { 1.year.ago.beginning_of_day }
    end
  end

  factory :additional_code_type_description do
    additional_code_type_id                { generate(:additional_code_type_id) }
    description                            { Forgery(:lorem_ipsum).sentence }
    language_id                            { 'IT' }

    trait :xml do
      language_id { 'EN' }
    end
  end

  factory :meursing_additional_code do
    meursing_additional_code_sid { generate(:meursing_additional_code_sid) }
    additional_code         { Forgery(:basic).text(exactly: 3) }
    validity_start_date     { 2.years.ago.beginning_of_day }
    validity_end_date       { nil }
  end

  factory :additional_code_type_measure_type do |f|
    f.measure_type_id { Forgery(:basic).text(exactly: 3) }
    f.additional_code_type_id { generate(:additional_code_type_id) }
    f.validity_start_date     { 2.years.ago.beginning_of_day }
    f.validity_end_date       { nil }

    f.measure_type         { create :measure_type, measure_type_id: }
    f.additional_code_type { create :additional_code_type, additional_code_type_id: }
  end
end
