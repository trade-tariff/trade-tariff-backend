module Api
  module V2
    module Measures
      class MeasurePresenter < SimpleDelegator
        delegate :id, to: :duty_expression, prefix: true
        delegate :authorised_use_provisions_submission?, to: :measure_type

        def initialize(measure, declarable)
          super(measure)

          @measure = measure
          @declarable = declarable
        end

        def excise
          excise?
        end

        def vat
          vat?
        end

        def universal_waiver_applies
          universal_waiver_applies?
        end

        def duty_expression
          Api::V2::Measures::DutyExpressionPresenter.new(self, @declarable)
        end

        def national_measurement_units
          @national_measurement_units ||= @declarable.national_measurement_unit_set
                                                    &.national_measurement_unit_set_units
                                                    &.select(&:present?)
                                                    &.select { |nmu| nmu.level > 1 } || []
        end

        def additional_code
          export_refund_nomenclature || super
        end

        def additional_code_id
          export_refund_nomenclature_sid || additional_code_sid
        end

        def measure_condition_ids
          measure_conditions.pluck(:measure_condition_sid)
        end

        def measure_component_ids
          measure_components.map(&:id)
        end

        def resolved_measure_component_ids
          resolved_measure_components.map(&:id)
        end

        def national_measurement_unit_ids
          national_measurement_units.map { |unit| unit.pk.join('-') }
        end

        def excluded_geographical_area_ids
          excluded_geographical_areas.pluck(:geographical_area_id)
        end

        def footnote_ids
          footnotes&.map(&:code)
        end

        def legal_act_ids
          legal_acts.map(&:regulation_id)
        end

        def legal_acts
          super.map do |legal_act|
            Api::V2::Measures::MeasureLegalActPresenter.new legal_act, self
          end
        end

        def order_number_id
          order_number&.quota_order_number_id
        end

        def excluded_countries
          excluded_geographical_areas + measure_type_exclusions
        end

        def excluded_country_ids
          excluded_countries.map(&:id)
        end

        def scheme_code
          return nil unless rules_of_origin_apply?

          TradeTariffBackend.rules_of_origin.scheme_associations[geographical_area_id]
        end

        def measure_condition_permutation_groups
          @measure_condition_permutation_groups = \
            MeasureConditionPermutations::Calculator.new(@measure)
                                                    .permutation_groups
        end

        def measure_condition_permutation_group_ids
          measure_condition_permutation_groups.map(&:id)
        end

        def preference_code_id
          preference_code&.id
        end

        def preference_code
          PreferenceCode.build(@declarable, self)
        end

        def special_nature?
          measure_conditions.any?(&:special_nature?)
        end

        def authorised_use?
          measure_conditions.any?(&:authorised_use?)
        end

        def find_legal_act(regulation_id)
          legal_acts.find { |legal_act| get_regulation_id(legal_act) == regulation_id }
        end

        def measure_generating_legal_act_id
          measure_generating_legal_act&.regulation_id
        end

        def measure_generating_legal_act
          mgla = find_legal_act(measure_generating_regulation_id)

          Api::V2::Measures::MeasureLegalActPresenter.new(mgla, self) if mgla
        end

        def justification_legal_act_id
          justification_regulation_id
        end

        def justification_legal_act
          if justification_regulation
            Api::V2::Measures::MeasureLegalActPresenter.new(justification_regulation, self)
          end
        end

      private

        def measure_type_exclusions
          @measure_type_exclusions ||= MeasureTypeExclusion.find_geographical_areas(
            measure_type_id,
            geographical_area_id,
          )
        end

        def get_regulation_id(legal_act)
          if legal_act.role == Measure::MODIFICATION_REGULATION_ROLE
            legal_act.modification_regulation_id
          else
            legal_act.base_regulation_id
          end
        end
      end
    end
  end
end
