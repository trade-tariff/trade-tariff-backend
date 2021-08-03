FactoryBot.define do
  sequence(:base_regulation_sid) { |n| n }

  factory :base_regulation do
    base_regulation_id   { generate(:sid) }
    base_regulation_role { 1 }
    validity_start_date { Date.current.ago(3.years) }
    validity_end_date   { nil }
    effective_end_date  { nil }
    information_text { 'This is some explanatory information text' }

    trait :abrogated do
      after(:build) do |br, _evaluator|
        FactoryBot.create(:complete_abrogation_regulation, complete_abrogation_regulation_id: br.base_regulation_id,
                                                           complete_abrogation_regulation_role: br.base_regulation_role)
      end
    end

    trait :uk_concatenated_regulation do
      officialjournal_number { '1' }
      officialjournal_page { 1 }

      transient do
        uk_regulation_code { 'S.I. 2019/16' }
        uk_regulation_url { 'https://www.legislation.gov.uk/uksi/2019/16' }
        uk_description do
          'The Leghold Trap and Pelt Imports (Amendment etc.) (EU Exit) Regulations 2019'
        end
      end

      information_text { [uk_description, uk_regulation_code, uk_regulation_url].compact.join("\xC2\xA0") }
    end
  end
end
