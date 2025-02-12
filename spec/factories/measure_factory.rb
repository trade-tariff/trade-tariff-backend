FactoryBot.define do
  sequence(:measure_sid) { |n| n }
  # offset sequence id to avoid conflicting with special casing of certain measure
  # types in the code base
  sequence(:measure_type_id, 10_000) { |n| n }

  factory :measure do
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
      generating_regulation { nil }
      default_start_date { 3.years.ago.beginning_of_day }
      additional_code { nil }
      goods_nomenclature { nil }
      for_geo_area { nil }
      certificate { nil }
      trade_movement_code { MeasureType::IMPORT_MOVEMENT_CODES.sample }
      excluded_geographical_areas { [] }
      created_at { Time.zone.now }
    end

    filename { build(:cds_update, issue_date: operation_date || validity_start_date).filename }

    measure_sid { generate(:measure_sid) }
    measure_type_id { generate(:measure_type_id) }
    measure_generating_regulation_id { generating_regulation&.regulation_id || generate(:base_regulation_sid) }
    measure_generating_regulation_role { generating_regulation&.role || Measure::BASE_REGULATION_ROLE }
    additional_code_id { additional_code&.additional_code }
    additional_code_sid { additional_code&.additional_code_sid }
    additional_code_type_id { additional_code&.additional_code_type_id }
    goods_nomenclature_sid { goods_nomenclature&.goods_nomenclature_sid || generate(:goods_nomenclature_sid) }
    goods_nomenclature_item_id { goods_nomenclature&.goods_nomenclature_item_id || 10.times.map { Random.rand(9) }.join }
    geographical_area_sid { for_geo_area&.geographical_area_sid || generate(:geographical_area_sid) }
    geographical_area_id { for_geo_area&.geographical_area_id || generate(:geographical_area_id) }
    validity_start_date { default_start_date }
    validity_end_date   { nil }
    reduction_indicator { 1 }

    measure_type do
      create :measure_type, measure_type_id:,
                            validity_start_date: (validity_start_date || default_start_date) - 1.day,
                            measure_explosion_level: type_explosion_level,
                            order_number_capture_code:,
                            trade_movement_code:,
                            measure_type_series_id:
    end

    geographical_area do
      for_geo_area || create(
        :geographical_area,
        :with_description,
        geographical_area_sid:,
        geographical_area_id:,
        validity_start_date: (validity_start_date || default_start_date) - 1.day,
      )
    end

    after(:create) do |measure, evaluator|
      if evaluator.certificate
        create :measure_condition, measure:, certificate: evaluator.certificate
      end

      evaluator.excluded_geographical_areas.each do |area|
        create :measure_excluded_geographical_area,
               measure_sid: measure.measure_sid,
               for_geo_area: area
      end
    end

    trait :with_gsp do
      with_gsp_enhanced_framework
    end

    trait :with_authorised_use_provisions_submission do
      measure_type_id { '464' }
    end

    trait :with_special_nature do
      certificate_type_code { 'A' }
      certificate_code { '990' }
    end

    trait :with_authorised_use do
      certificate_type_code { 'N' }
      certificate_code { '990' }
    end

    trait :with_gsp_least_developed_countries do
      geographical_area_id { '2005' }
    end

    trait :with_gsp_general_framework do
      geographical_area_id { '2020' }
    end

    trait :with_gsp_enhanced_framework do
      geographical_area_id { '2027' }
    end

    trait :with_special_nature do
      certificate_type_code { 'A' }
      certificate_code { '990' }
    end

    trait :with_authorised_use do
      certificate_type_code { 'N' }
      certificate_code { '990' }
    end

    trait :with_inactive_goods_nomenclature do
      after(:create) do |measure, evaluator|
        create(
          :goods_nomenclature,
          validity_start_date: measure.validity_start_date - 1.day,
          validity_end_date: measure.validity_start_date,
          goods_nomenclature_item_id: measure.goods_nomenclature_item_id,
          goods_nomenclature_sid: measure.goods_nomenclature_sid,
          producline_suffix: evaluator.gono_producline_suffix,
          indents: evaluator.gono_number_indents,
        )
      end
    end

    trait :with_base_regulation do
      generating_regulation { create(:base_regulation) }
    end

    trait :with_unapproved_base_regulation do
      generating_regulation { create(:base_regulation, :unapproved) }
    end

    trait :with_justification_regulation do
      after(:create) do |measure, _evaluator|
        measure.update(justification_regulation_id: 12_345, justification_regulation_role: Measure::BASE_REGULATION_ROLE)

        create(:base_regulation,
               base_regulation_id: measure.justification_regulation_id,
               base_regulation_role: measure.justification_regulation_role,
               effective_end_date: nil)
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
        create(:goods_nomenclature,
               validity_start_date: validity_start_date - 1.day,
               producline_suffix: gono_producline_suffix,
               indents: gono_number_indents)
      end
      # noop
    end

    trait :with_goods_nomenclature_with_heading do
      with_goods_nomenclature

      after(:create) do |measure, _evaluator|
        create(:heading, goods_nomenclature_item_id: "#{measure.goods_nomenclature_item_id.first(4)}000000")
        measure.reload
      end
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

    trait :preferential_quota do
      measure_type_id { '143' }
    end

    trait :third_country do
      measure_type_id { MeasureType::THIRD_COUNTRY.sample }
    end

    trait :erga_omnes do
      geographical_area_id { GeographicalArea::ERGA_OMNES_ID }
    end

    trait :areas_subject_to_vat_or_excise do
      geographical_area_id { GeographicalArea::AREAS_SUBJECT_TO_VAT_OR_EXCISE_ID }
    end

    trait :simplified_procedural_code do
      erga_omnes
      with_measure_components

      transient do
        simplified_procedural_code { '123' }
        goods_nomenclature_label { Forgery(:basic).text }
      end

      measure_type_id { '488' }
      validity_start_date { Time.zone.today }
      validity_end_date { Time.zone.today + 2.weeks }

      after(:build) do |measure, evaluator|
        if SimplifiedProceduralCode.where(simplified_procedural_code: evaluator.simplified_procedural_code).none?
          create(
            :simplified_procedural_code,
            goods_nomenclature_item_id: measure.goods_nomenclature_item_id,
            goods_nomenclature_label: evaluator.goods_nomenclature_label,
            simplified_procedural_code: evaluator.simplified_procedural_code,
          )
        end
      end
    end

    trait :with_liters_of_pure_alcohol_measure_component do
      with_measure_components

      transient do
        measurement_unit_code { 'LPA' }
        measurement_unit_qualifier_code {}
      end
    end

    trait :with_percentage_alcohol_and_volume_per_hl_component do
      with_measure_components

      transient do
        measurement_unit_code { 'ASV' }
        measurement_unit_qualifier_code { 'X' }
      end
    end

    trait :third_country_overview do
      erga_omnes
      third_country
    end

    trait :vat do
      measure_type_id { '305' }
    end

    trait :vat_overview do
      vat
      areas_subject_to_vat_or_excise
    end

    trait :supplementary do
      measure_type_id { MeasureType::SUPPLEMENTARY_TYPES.sample }

      after(:create)  do |measure, _evaluator|
        create(:measure_component, :with_measure_unit, measure_sid: measure.measure_sid)
      end
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
      measure_type_id { '306' }
    end

    trait :mfn do
      with_measure_components
      with_measure_type
      third_country
      duty_amount { 1 }
    end

    trait :single_unit do
      measurement_unit_code { 'DTN' }
      measurement_unit_qualifier_code { 'R' }
    end

    trait :compound_unit do
      measurement_unit_code { 'ASV' }
      measurement_unit_qualifier_code { 'X' }
    end

    trait :with_footnote_association do
      after(:build) do |measure, _evaluator|
        create(
          :footnote,
          :with_measure_association,
          measure_sid: measure.measure_sid,
        )
      end
    end

    trait :with_measure_components do
      after(:build) do |measure, evaluator|
        create_list(
          :measure_component,
          evaluator.measure_components_count,
          :with_duty_expression,
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
        condition_measurement_unit_code { nil }
        condition_measurement_unit_qualifier_code { nil }
        condition_code { 'B' }
        certificate_type_code { nil }
        certificate_code { nil }
        exempting_certificate_override { false }
      end

      after(:build) do |measure, evaluator|
        condition = create(
          :measure_condition,
          measure_sid: measure.measure_sid,
          condition_measurement_unit_code: evaluator.condition_measurement_unit_code || evaluator.measurement_unit_code,
          condition_measurement_unit_qualifier_code: evaluator.condition_measurement_unit_qualifier_code || evaluator.measurement_unit_qualifier_code,
          condition_code: evaluator.condition_code,
          certificate_type_code: evaluator.certificate_type_code,
          certificate_code: evaluator.certificate_code,
          action_code: '01',
        )

        if evaluator.certificate_type_code.present? || evaluator.certificate_code.present?
          has_5a = Appendix5a.where(
            certificate_type_code: evaluator.certificate_type_code,
            certificate_code: evaluator.certificate_code,
          ).any?

          unless has_5a
            create(
              :appendix_5a,
              certificate_type_code: evaluator.certificate_type_code,
              certificate_code: evaluator.certificate_code,
            )
          end
        end

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

        if evaluator.certificate_type_code.present? || evaluator.certificate_code.present?
          create(
            :certificate,
            certificate_type_code: evaluator.certificate_type_code,
            certificate_code: evaluator.certificate_code,
            exempting_certificate_override: evaluator.exempting_certificate_override,
          )
        end
      end
    end

    trait :with_measure_excluded_geographical_area do
      for_geo_area do
        create :geographical_area, :with_description, :with_members
      end

      excluded_geographical_areas do
        [for_geo_area.contained_geographical_areas.first]
      end
    end

    trait :with_measure_excluded_geographical_area_group do
      for_geo_area do
        create :geographical_area, :with_description, :with_members
      end

      excluded_geographical_areas do
        create_list :geographical_area, 1, members: [for_geo_area.contained_geographical_areas.first]
      end
    end

    trait :with_measure_excluded_geographical_area_referenced_group do
      for_geo_area do
        create :geographical_area, :with_description, :with_members
      end

      excluded_geographical_areas do
        # Referencee
        create :geographical_area,
               geographical_area_id: GeographicalArea::REFERENCED_GEOGRAPHICAL_AREAS.first.last,
               members: [for_geo_area.contained_geographical_areas.first]

        # Referencer
        create_list :geographical_area, 1,
                    geographical_area_id: GeographicalArea::REFERENCED_GEOGRAPHICAL_AREAS.first.first
      end
    end

    trait :with_measure_partial_temporary_stop do
      after(:build) do |measure, _evaluator|
        create(:measure_partial_temporary_stop, measure_sid: measure.measure_sid)
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
      measure_generating_regulation_role { Measure::MODIFICATION_REGULATION_ROLE }

      generating_regulation { create(:modification_regulation, :approved) }
    end

    trait :with_unapproved_modification_regulation do
      measure_generating_regulation_role { Measure::MODIFICATION_REGULATION_ROLE }

      generating_regulation { create(:modification_regulation, :unapproved) }
    end

    trait :with_abrogated_modification_regulation do
      measure_generating_regulation_role { Measure::MODIFICATION_REGULATION_ROLE }

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
        additional_code_description { Forgery(:basic).text }
      end

      after(:build) do |measure, evaluator|
        adco = create(
          :additional_code,
          :with_description,
          additional_code_type_id: measure.additional_code_type_id,
          additional_code: evaluator.additional_code_id.presence || generate(:additional_code_id),
          additional_code_description: evaluator.additional_code_description,
        )
        measure.additional_code_sid = adco.additional_code_sid
        measure.additional_code_id = adco.additional_code
        measure.additional_code_type_id = adco.additional_code_type_id
        measure.save
      end
    end

    trait :with_exempting_additional_code do
      transient do
        additional_code_description { Forgery(:basic).text }
      end

      additional_code_id { '000' }
      additional_code_type_id { '7' }

      after(:build) do |measure, evaluator|
        adco = create(
          :additional_code,
          :with_description,
          :with_exempting_additional_code_override,
          additional_code_type_id: measure.additional_code_type_id,
          additional_code: evaluator.additional_code_id.presence || generate(:additional_code_id),
          additional_code_description: evaluator.additional_code_description,
        )
        measure.additional_code_sid = adco.additional_code_sid
        measure.additional_code_id = adco.additional_code
        measure.additional_code_type_id = adco.additional_code_type_id
        measure.save
      end
    end

    trait :with_additional_code_type do
      before(:build) do |measure, _evaluator|
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
      ordernumber { generate(:quota_order_number_id) }

      after(:build) do |measure, _evaluator|
        create(:quota_order_number, quota_order_number_id: measure.ordernumber)
      end
    end

    trait :with_quota_definition do
      with_quota_order_number

      transient do
        initial_volume { 1000 }
      end

      after(:build) do |measure, evaluator|
        create(
          :quota_definition,
          quota_order_number_id: measure.ordernumber,
          initial_volume: evaluator.initial_volume,
        )
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
    trade_movement_code { 0 }

    trait :export do
      trade_movement_code { 1 }
    end

    trait :import do
      trade_movement_code { 0 }
    end

    trait :vat do
      measure_type_id { 'VTZ' } # CHIEF VAT type
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
