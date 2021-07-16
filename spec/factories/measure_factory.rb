FactoryBot.define do
  sequence(:measure_sid) { |n| n }
  sequence(:measure_type_id) { |n| n }
  sequence(:measure_condition_sid) { |n| n }

  factory :measure do |f|
    transient do
      type_explosion_level { 10 }
      gono_number_indents { 1 }
      gono_producline_suffix { '80' }
      order_number_capture_code { 2 }
      duty_amount { Forgery(:basic).number }
      measure_components_count { 1 }
      duty_expression_id { '02' }
      measurement_unit_code { 'DTN' }
      measurement_unit_qualifier_code { 'R' }
      monetary_unit_code { nil }
      measure_type_series_id { 'S' }
    end

    f.measure_sid { generate(:measure_sid) }
    f.measure_type_id { generate(:measure_type_id) }
    f.measure_generating_regulation_id { generate(:base_regulation_sid) }
    f.measure_generating_regulation_role { 1 }
    f.additional_code_type_id { generate(:additional_code_type_id) }
    f.goods_nomenclature_sid { generate(:goods_nomenclature_sid) }
    f.goods_nomenclature_item_id { 10.times.map { Random.rand(9) }.join }
    f.geographical_area_sid { generate(:geographical_area_sid) }
    f.geographical_area_id { generate(:geographical_area_id) }
    f.validity_start_date { Date.current.ago(3.years) }
    f.validity_end_date   { nil }
    f.reduction_indicator { [nil, 1, 2, 3][Random.rand(4)] }

    # mandatory valid associations
    f.goods_nomenclature do
      create :goods_nomenclature, validity_start_date: validity_start_date - 1.day,
                                  goods_nomenclature_item_id: goods_nomenclature_item_id,
                                  goods_nomenclature_sid: goods_nomenclature_sid,
                                  producline_suffix: gono_producline_suffix,
                                  indents: gono_number_indents
    end

    f.measure_type do
      create :measure_type, measure_type_id: measure_type_id,
                            validity_start_date: validity_start_date - 1.day,
                            measure_explosion_level: type_explosion_level,
                            order_number_capture_code: order_number_capture_code,
                            trade_movement_code: MeasureType::IMPORT_MOVEMENT_CODES.sample,
                            measure_type_series_id: measure_type_series_id
    end
    f.geographical_area do
      create(:geographical_area, geographical_area_sid: geographical_area_sid,
                                 geographical_area_id: geographical_area_id,
                                 validity_start_date: validity_start_date - 1.day)
    end
    f.base_regulation do
      create(:base_regulation, base_regulation_id: measure_generating_regulation_id,
                               base_regulation_role: measure_generating_regulation_role,
                               effective_end_date: Date.current.in(10.years))
    end

    trait :national do
      sequence(:measure_sid) { |n| -1 * n }
      national { true }
    end

    trait :invalidated do
      invalidated_at { Time.now }
    end

    trait :with_goods_nomenclature do
      # noop
    end

    trait :with_measure_type do
      transient do
        measure_type_description { Forgery(:basic).text }
      end

      after(:build) do |measure, evaluator|
        create(
          :measure_type,
          measure_type_description: evaluator.measure_type_description,
          measure_type_id: measure.measure_type_id,
          validity_start_date: measure.validity_start_date - 1.day,
          measure_explosion_level: evaluator.type_explosion_level,
          order_number_capture_code: evaluator.order_number_capture_code,
          trade_movement_code: MeasureType::IMPORT_MOVEMENT_CODES.sample,
          measure_type_series_id: evaluator.measure_type_series_id,
        )
      end
    end

    trait :ad_valorem do
      duty_expression_id { '01' }
      measurement_unit_code { nil }
      monetary_unit_code { nil }
    end

    trait :no_ad_valorem do
      duty_expression_id { '02' }
      measurement_unit_code { 'DTN' }
      monetary_unit_code { nil }
    end

    trait :expresses_units do
      measure_type_series_id { 'C' }
    end

    trait :no_expresses_units do
      measure_type_series_id { 'S' }
    end

    trait :third_country do
      measure_type_id { MeasureType::THIRD_COUNTRY.sample }
    end

    trait :with_measure_components do
      after(:build) do |measure, evaluator|
        FactoryBot.create_list(
          :measure_component,
          evaluator.measure_components_count,
          measure_sid: measure.measure_sid,
          duty_amount: evaluator.duty_amount,
          duty_expression_id: evaluator.duty_expression_id,
          measurement_unit_code: evaluator.measurement_unit_code,
          measurement_unit_qualifier_code: evaluator.measurement_unit_qualifier_code,
          monetary_unit_code: evaluator.monetary_unit_code,
        )
      end
    end

    trait :with_measure_conditions do
      after(:build) do |measure, evaluator|
        condition = FactoryBot.create(
          :measure_condition,
          measure_sid: measure.measure_sid,
          condition_measurement_unit_code: evaluator.measurement_unit_code,
          condition_measurement_unit_qualifier_code: evaluator.measurement_unit_qualifier_code,
        )

        FactoryBot.create(
          :measure_condition_component,
          measure_condition_sid: condition.measure_condition_sid,
          duty_amount: evaluator.duty_amount,
          duty_expression_id: evaluator.duty_expression_id,
          measurement_unit_code: evaluator.measurement_unit_code,
          measurement_unit_qualifier_code: evaluator.measurement_unit_qualifier_code,
          monetary_unit_code: evaluator.monetary_unit_code,
        )
      end
    end

    trait :with_modification_regulation do
      measure_generating_regulation_role { 4 }

      after(:build) do |measure, _evaluator|
        FactoryBot.create(:modification_regulation, modification_regulation_id: measure.measure_generating_regulation_id)
      end
    end

    trait :with_abrogated_modification_regulation do
      measure_generating_regulation_role { 4 }

      after(:build) do |measure, _evaluator|
        base_regulation = FactoryBot.create(:base_regulation, :abrogated)
        FactoryBot.create(:modification_regulation,
                          modification_regulation_id: measure.measure_generating_regulation_id,
                          modification_regulation_role: measure.measure_generating_regulation_role,
                          base_regulation_id: base_regulation.base_regulation_id,
                          base_regulation_role: base_regulation.base_regulation_role)
      end
    end

    trait :with_geographical_area do
      # noop
    end

    trait :with_additional_code do
      transient do
        additional_code { Forgery(:basic).text(exactly: 3) }
        additional_code_description { Forgery(:basic).text }
      end

      after(:build) do |measure, evaluator|
        adco = FactoryBot.create(
          :additional_code,
          :with_description,
          additional_code_type_id: measure.additional_code_type_id,
          additional_code: evaluator.additional_code,
          additional_code_description: evaluator.additional_code_description,
        )
        measure.additional_code_sid = adco.additional_code_sid
        measure.additional_code_id = adco.additional_code
        measure.additional_code_type_id = adco.additional_code_type_id
        measure.save
      end
    end

    trait :with_additional_code_type do
      after(:build) do |measure, _evaluator|
        FactoryBot.create(:additional_code_type, additional_code_type_id: measure.additional_code_type_id)
      end
    end

    trait :with_related_additional_code_type do
      after(:build) do |measure, _evaluator|
        FactoryBot.create(:additional_code_type_measure_type, additional_code_type_id: measure.additional_code_type_id,
                                                              measure_type_id: measure.measure_type_id)
      end
    end

    trait :with_quota_order_number do
      after(:build) do |measure, _evaluator|
        FactoryBot.create(:quota_order_number, quota_order_number_id: measure.ordernumber)
      end
    end
  end

  factory :measure_type do
    transient do
      measure_type_description { Forgery(:basic).text }
    end

    measure_type_id { generate(:measure_type_id) }
    sequence(:measure_type_series_id, LoopingSequence.lower_a_to_upper_z, &:value)
    validity_start_date    { Date.current.ago(3.years) }
    validity_end_date      { nil }
    measure_explosion_level { 10 }
    order_number_capture_code { 10 }

    trait :export do
      trade_movement_code { 1 }
    end

    trait :import do
      trade_movement_code { 0 }
    end

    trait :national do
      national { true }
    end

    trait :non_national do
      national { false }
    end

    trait :excise do
      measure_type_series_id { 'Q' }
      measure_type_description { 'EXCISE 111' }
    end

    after(:build) do |measure_type, _evaluator|
      FactoryBot.create(:measure_type_series, measure_type_series_id: measure_type.measure_type_series_id)
    end

    after(:build) do |measure_type, evaluator|
      FactoryBot.create(
        :measure_type_description,
        measure_type_id: measure_type.measure_type_id,
        description: evaluator.measure_type_description,
      )
    end
  end

  factory :measure_type_description do
    measure_type_id { generate(:measure_type_id) }
    description { Forgery(:basic).text }
  end

  factory :measure_condition do
    measure_condition_sid { generate(:measure_condition_sid) }
    measure_sid { generate(:measure_sid) }
    condition_code { Forgery(:basic).text(exactly: 2) }
    component_sequence_number { Forgery(:basic).number }
    condition_duty_amount { Forgery(:basic).number }
    condition_monetary_unit_code { Forgery(:basic).text(exactly: 3) }
    condition_measurement_unit_code { Forgery(:basic).text(exactly: 3) }
    sequence(:condition_measurement_unit_qualifier_code, LoopingSequence.lower_a_to_upper_z, &:value)
    sequence(:action_code, LoopingSequence.lower_a_to_upper_z, &:value)
    sequence(:certificate_type_code, LoopingSequence.lower_a_to_upper_z, &:value)
    certificate_code { Forgery(:basic).text(exactly: 3) }
  end
end
