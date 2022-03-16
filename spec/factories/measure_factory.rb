FactoryBot.define do
  sequence(:measure_sid) { |n| n }
  # offset sequence id to avoid conflicting with special casing of certain measure
  # types in the code base
  sequence(:measure_type_id, 10_000) { |n| n }

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
      base_regulation_effective_end_date { nil }
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
    f.validity_start_date { 3.years.ago.beginning_of_day }
    f.validity_end_date   { nil }
    f.reduction_indicator { [nil, 1, 2, 3].sample }

    f.goods_nomenclature do
      create(
        :goods_nomenclature,
        validity_start_date: validity_start_date - 1.day,
        goods_nomenclature_item_id:,
        goods_nomenclature_sid:,
        producline_suffix: gono_producline_suffix,
        indents: gono_number_indents,
      )
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
      create(:geographical_area, geographical_area_sid:,
                                 geographical_area_id:,
                                 validity_start_date: validity_start_date - 1.day)
    end

    trait :with_base_regulation do
      after(:create) do |measure, evaluator|
        create(
          :base_regulation,
          base_regulation_id: measure.measure_generating_regulation_id,
          base_regulation_role: measure.measure_generating_regulation_role,
          effective_end_date: evaluator.base_regulation_effective_end_date || Time.zone.today.in(10.years),
        )
      end
    end

    trait :national do
      sequence(:measure_sid) { |n| -1 * n }
      national { true }
    end

    trait :invalidated do
      invalidated_at { Time.zone.now }
    end

    trait :with_goods_nomenclature do
      goods_nomenclature do
        create(
          :goods_nomenclature,
          validity_start_date: validity_start_date - 1.day,
          goods_nomenclature_item_id:,
          goods_nomenclature_sid:,
          producline_suffix: gono_producline_suffix,
          indents: gono_number_indents,
        )
      end
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
          trade_movement_code: 2,
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
    end

    trait :expresses_units do
      measure_type_series_id { 'C' }
    end

    trait :no_expresses_units do
      measure_type_series_id { 'S' }
    end

    trait :tariff_preference do
      measure_type_id { '142' }
    end

    trait :third_country do
      measure_type_id { MeasureType::THIRD_COUNTRY.sample }
    end

    trait :vat do
      measure_type_id { '305' }
    end

    trait :supplementary do
      measure_type_id { MeasureType::SUPPLEMENTARY_TYPES.sample }
    end

    trait :trade_remedy do
      measure_type_id { '551' }
    end

    trait :flour do
      measure_type_id { '672' }
    end

    trait :sugar do
      measure_type_id { '673' }
    end

    trait :agricultural do
      measure_type_id { '674' }
    end

    trait :excise do
      measure_type { create(:measure_type, measure_type_series_id: 'Q', measure_type_id: '306') }
    end

    trait :single_unit do
      measurement_unit_code { 'DTN' }
      measurement_unit_qualifier_code { 'R' }
    end

    trait :compound_unit do
      measurement_unit_code { 'ASV' }
      measurement_unit_qualifier_code { 'X' }
    end

    trait :with_measure_components do
      after(:build) do |measure, evaluator|
        create_list(
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

    trait :with_meursing do
      transient do
        duty_expression_id { 12 }
      end
    end

    trait :without_meursing do
      transient do
        duty_expression_id { 4 }
      end
    end

    trait :with_measure_conditions do
      transient do
        condition_code { 'B' }
        certificate_type_code { nil }
        certificate_code { nil }
      end

      after(:build) do |measure, evaluator|
        condition = create(
          :measure_condition,
          measure_sid: measure.measure_sid,
          condition_measurement_unit_code: evaluator.measurement_unit_code,
          condition_measurement_unit_qualifier_code: evaluator.measurement_unit_qualifier_code,
          condition_code: evaluator.condition_code,
          certificate_type_code: evaluator.certificate_type_code,
          certificate_code: evaluator.certificate_code,
        )

        create(
          :measure_condition_component,
          :with_duty_expression,
          measure_condition_sid: condition.measure_condition_sid,
          duty_amount: evaluator.duty_amount,
          duty_expression_id: evaluator.duty_expression_id,
          measurement_unit_code: evaluator.measurement_unit_code,
          measurement_unit_qualifier_code: evaluator.measurement_unit_qualifier_code,
          monetary_unit_code: evaluator.monetary_unit_code,
        )
      end
    end

    trait :with_entry_price_system do
      transient do
        condition_code { 'V' }
      end
    end

    trait :without_entry_price_system do
      transient do
        condition_code { 'B' }
      end
    end

    trait :with_modification_regulation do
      measure_generating_regulation_role { 4 }

      after(:build) do |measure, _evaluator|
        create(:modification_regulation, modification_regulation_id: measure.measure_generating_regulation_id)
      end
    end

    trait :with_abrogated_modification_regulation do
      measure_generating_regulation_role { 4 }

      after(:build) do |measure, _evaluator|
        base_regulation = create(:base_regulation, :abrogated)
        create(:modification_regulation,
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
        adco = create(
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
        create(:additional_code_type, additional_code_type_id: measure.additional_code_type_id)
      end
    end

    trait :with_related_additional_code_type do
      after(:build) do |measure, _evaluator|
        create(:additional_code_type_measure_type, additional_code_type_id: measure.additional_code_type_id,
                                                   measure_type_id: measure.measure_type_id)
      end
    end

    trait :with_quota_order_number do
      after(:build) do |measure, _evaluator|
        create(:quota_order_number, quota_order_number_id: measure.ordernumber)
      end
    end
  end

  factory :measure_type do
    transient do
      measure_type_description { Forgery(:basic).text }
    end

    measure_type_id { generate(:measure_type_id) }
    sequence(:measure_type_series_id, LoopingSequence.lower_a_to_upper_z, &:value)
    validity_start_date    { 3.years.ago.beginning_of_day }
    validity_end_date      { nil }
    measure_explosion_level { 10 }
    order_number_capture_code { 10 }

    trait :export do
      trade_movement_code { 1 }
    end

    trait :import do
      trade_movement_code { 0 }
    end

    trait :import_and_export do
      trade_movement_code { 2 }
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

    trait :with_measure_type_series_description do |_variable|
      after(:build) do |measure_type|
        measure_type.measure_type_series_description = create(:measure_type_series_description)
      end
    end

    after(:build) do |measure_type, _evaluator|
      create(:measure_type_series, measure_type_series_id: measure_type.measure_type_series_id)
    end

    after(:build) do |measure_type, evaluator|
      create(:measure_type_description,
             measure_type_id: measure_type.measure_type_id,
             description: evaluator.measure_type_description)
    end
  end

  factory :measure_type_description do
    measure_type_id { generate(:measure_type_id) }
    description { Forgery(:basic).text }
  end

  factory :meursing_measure, parent: :measure, class: 'MeursingMeasure' do
    transient do
      root_measure {}
      duty_amount { 0.0 }
      duty_expression_id { '01' }
      measurement_unit_code { 'DTN' }
      monetary_unit_code { 'EUR' }
      base_regulation_effective_end_date { nil }
    end

    additional_code_id { '000' }
    additional_code_type_id { '7' }
    goods_nomenclature { nil }
    goods_nomenclature_item_id { nil }
    goods_nomenclature_sid { nil }
    measure_type_id { '672' }
    reduction_indicator { '1' }
    validity_end_date { nil }

    after(:build) do |meursing_measure, evaluator|
      root_measure = evaluator.root_measure

      if root_measure
        meursing_measure.reduction_indicator = root_measure.reduction_indicator
        meursing_measure.geographical_area_id = root_measure.geographical_area_id

        meursing_measure.save
      end
    end
  end
end
