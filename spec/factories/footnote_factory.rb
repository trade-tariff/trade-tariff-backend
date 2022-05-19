FactoryBot.define do
  sequence(:footnote_sid) { |n| n }

  factory :footnote do
    transient do
      valid_at { 2.years.ago.beginning_of_day }
      valid_to { nil }
      goods_nomenclature_sid { generate(:goods_nomenclature_sid) }
      measure_sid { generate(:measure_sid) }
    end

    footnote_id      { Forgery(:basic).text(exactly: 3) }
    footnote_type_id { Forgery(:basic).text(exactly: 2) }
    validity_start_date     { 2.years.ago.beginning_of_day }
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
      after(:create) do |footnote, evaluator|
        create(
          :footnote_association_goods_nomenclature,
          goods_nomenclature_sid: evaluator.goods_nomenclature_sid,
          footnote:,
          validity_start_date: evaluator.valid_at,
          validity_end_date: evaluator.valid_to,
        )
      end
    end

    trait :with_measure_association do
      after(:create) do |footnote, evaluator|
        create(
          :footnote_association_measure,
          measure_sid: evaluator.measure_sid,
          footnote_id: footnote.footnote_id,
          footnote_type_id: footnote.footnote_type_id,
        )
      end
    end

    trait :with_additional_code_association do
      after(:create) do |footnote, _evaluator|
        create(
          :footnote_association_additional_code,
          footnote_id: footnote.footnote_id,
          footnote_type_id: footnote.footnote_type_id,
        )
      end
    end

    trait :with_meursing_heading_association do
      after(:create) do |footnote, _evaluator|
        create(
          :footnote_association_meursing_heading,
          footnote_id: footnote.footnote_id,
          footnote_type: footnote.footnote_type_id,
        )
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
    validity_start_date                    { 2.years.ago.beginning_of_day }
    validity_end_date                      { nil }
  end

  factory :footnote_description do
    transient do
      valid_at { 2.years.ago.beginning_of_day }
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
    transient do
      footnote {}
      goods_nomenclature {}
    end

    goods_nomenclature_sid do
      goods_nomenclature.try(:goods_nomenclature_sid) || generate(:goods_nomenclature_sid)
    end

    footnote_id do
      footnote.try(:footnote_id) || Forgery(:basic).text(exactly: 3)
    end

    footnote_type do
      footnote.try(:footnote_type_id) || Forgery(:basic).text(exactly: 2)
    end

    validity_start_date { 3.years.ago.beginning_of_day }
    validity_end_date   { nil }
  end

  factory :footnote_association_ern do
    export_refund_nomenclature_sid  { generate(:export_refund_nomenclature_sid) }
    footnote_id                     { Forgery(:basic).text(exactly: 3) }
    footnote_type                   { Forgery(:basic).text(exactly: 2) }
    validity_start_date             { 2.years.ago.beginning_of_day }
    validity_end_date               { nil }
  end

  factory :footnote_association_measure do
    transient do
      footnote {}
      measure {}
    end

    measure_sid do
      measure.try(:measure_sid) || generate(:measure_sid)
    end

    footnote_id do
      footnote.try(:footnote_id) || Forgery(:basic).text(exactly: 3)
    end

    footnote_type_id do
      footnote.try(:footnote_type_id) || Forgery(:basic).text(exactly: 2)
    end
  end

  factory :footnote_association_additional_code do
    additional_code_sid             { generate(:additional_code_sid) }
    footnote_id                     { Forgery(:basic).text(exactly: 3) }
    footnote_type_id                { Forgery(:basic).text(exactly: 2) }
    validity_start_date             { 2.years.ago.beginning_of_day }
    validity_end_date               { nil }
  end

  factory :footnote_association_meursing_heading do
    meursing_table_plan_id          { Forgery(:basic).text(exactly: 2) }
    meursing_heading_number         { Forgery(:basic).number }
    footnote_id                     { Forgery(:basic).text(exactly: 3) }
    footnote_type                   { Forgery(:basic).text(exactly: 2) }
    validity_start_date             { 2.years.ago.beginning_of_day }
    validity_end_date               { nil }
  end

  factory :footnote_type do
    footnote_type_id { Forgery(:basic).text(exactly: 2) }
    validity_start_date { 2.years.ago.beginning_of_day }
    validity_end_date   { nil }
  end

  factory :footnote_type_description do
    footnote_type_id { Forgery(:basic).text(exactly: 2) }
    description      { Forgery(:basic).text }
  end
end
