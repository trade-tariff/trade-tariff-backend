FactoryBot.define do
  sequence(:footnote_sid) { |n| n }

  factory :footnote do
    transient do
      valid_at { Date.current.ago(2.years) }
      valid_to { nil }
      goods_nomenclature_sid { generate(:goods_nomenclature_sid) }
    end

    footnote_id      { Forgery(:basic).text(exactly: 3) }
    footnote_type_id { Forgery(:basic).text(exactly: 2) }
    validity_start_date     { Date.current.ago(2.years).localtime }
    validity_end_date       { nil }

    after(:build) do |ftn, _evaluator|
      FactoryBot.create(:footnote_type, footnote_type_id: ftn.footnote_type_id,
                                        validity_start_date: ftn.validity_start_date - 1.day)
      ftn_desc_period = FactoryBot.create(:footnote_description_period, footnote_type_id: ftn.footnote_type_id,
                                                                        footnote_id: ftn.footnote_id,
                                                                        validity_start_date: ftn.validity_start_date)
      FactoryBot.create(:footnote_description, footnote_type_id: ftn.footnote_type_id,
                                               footnote_id: ftn.footnote_id,
                                               footnote_description_period_sid: ftn_desc_period.footnote_description_period_sid)
    end

    trait :with_gono_association do
      after(:create) do |ftn, evaluator|
        FactoryBot.create(:footnote_association_goods_nomenclature, goods_nomenclature_sid: evaluator.goods_nomenclature_sid,
                                                                    footnote_id: ftn.footnote_id,
                                                                    footnote_type: ftn.footnote_type_id,
                                                                    validity_start_date: evaluator.valid_at,
                                                                    validity_end_date: evaluator.valid_to)
      end
    end

    trait :national do
      national { true }
    end

    trait :non_national do
      national { false }
    end
  end

  factory :footnote_description_period do
    footnote_description_period_sid { generate(:footnote_sid) }
    footnote_id      { Forgery(:basic).text(exactly: 3) }
    footnote_type_id { Forgery(:basic).text(exactly: 2) }
    validity_start_date                    { Date.current.ago(2.years) }
    validity_end_date                      { nil }
  end

  factory :footnote_description do
    transient do
      valid_at { Date.current.ago(2.years) }
      valid_to { nil }
    end

    footnote_description_period_sid { generate(:footnote_sid) }
    footnote_id                     { Forgery(:basic).text(exactly: 3) }
    footnote_type_id                { Forgery(:basic).text(exactly: 2) }
    description                     { Forgery(:lorem_ipsum).sentence }

    trait :with_period do
      after(:create) do |ftn_description, evaluator|
        FactoryBot.create(:footnote_description_period, footnote_description_period_sid: ftn_description.footnote_description_period_sid,
                                                        footnote_id: ftn_description.footnote_id,
                                                        footnote_type_id: ftn_description.footnote_type_id,
                                                        validity_start_date: evaluator.valid_at,
                                                        validity_end_date: evaluator.valid_to)
      end
    end
  end

  factory :footnote_association_goods_nomenclature do
    goods_nomenclature_sid          { generate(:goods_nomenclature_sid) }
    footnote_id                     { Forgery(:basic).text(exactly: 3) }
    footnote_type                   { Forgery(:basic).text(exactly: 2) }
    validity_start_date             { Date.current.ago(3.years) }
    validity_end_date               { nil }
  end

  factory :footnote_association_ern do
    export_refund_nomenclature_sid  { generate(:export_refund_nomenclature_sid) }
    footnote_id                     { Forgery(:basic).text(exactly: 3) }
    footnote_type                   { Forgery(:basic).text(exactly: 2) }
    validity_start_date             { Date.current.ago(2.years) }
    validity_end_date               { nil }
  end

  factory :footnote_association_measure do
    measure_sid                     { generate(:measure_sid) }
    footnote_id                     { Forgery(:basic).text(exactly: 3) }
    footnote_type_id                { Forgery(:basic).text(exactly: 2) }
  end

  factory :footnote_association_additional_code do
    additional_code_sid             { generate(:additional_code_sid) }
    footnote_id                     { Forgery(:basic).text(exactly: 3) }
    footnote_type_id                { Forgery(:basic).text(exactly: 2) }
    validity_start_date             { Date.current.ago(2.years) }
    validity_end_date               { nil }
  end

  factory :footnote_association_meursing_heading do
    meursing_table_plan_id          { Forgery(:basic).text(exactly: 2) }
    meursing_heading_number         { Forgery(:basic).number }
    footnote_id                     { Forgery(:basic).text(exactly: 3) }
    footnote_type                   { Forgery(:basic).text(exactly: 2) }
    validity_start_date             { Date.current.ago(2.years) }
    validity_end_date               { nil }
  end

  factory :footnote_type do
    footnote_type_id { Forgery(:basic).text(exactly: 2) }
    validity_start_date { Date.current.ago(2.years) }
    validity_end_date   { nil }
  end

  factory :footnote_type_description do
    footnote_type_id { Forgery(:basic).text(exactly: 2) }
    description      { Forgery(:basic).text }
  end
end
