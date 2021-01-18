FactoryBot.define do
  factory :publication_sigle do
    code_type_id       { Forgery(:basic).text(exactly: 2) }
    code               { Forgery(:basic).text(exactly: 2) }
    sequence(:publication_code, LoopingSequence.lower_a_to_upper_z, &:value)
    publication_sigle { Forgery(:basic).text(exactly: 2) }
    validity_start_date   { Date.current.ago(2.years) }
    validity_end_date     { nil }

    trait :xml do
      validity_end_date { Date.current.ago(1.year) }
    end
  end
end
