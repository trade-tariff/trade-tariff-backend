FactoryBot.define do
  factory :publication_sigle do
    code_type_id       { Forgery(:basic).text(exactly: 2) }
    code               { Forgery(:basic).text(exactly: 2) }
    sequence(:publication_code, LoopingSequence.lower_a_to_upper_z, &:value)
    publication_sigle { Forgery(:basic).text(exactly: 2) }
    validity_start_date   { 2.years.ago.beginning_of_day }
    validity_end_date     { nil }

    trait :xml do
      validity_end_date { 1.year.ago.beginning_of_day }
    end
  end
end
