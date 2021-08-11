module Api
  module V2
    module Measures
      class MeasurePresenter < SimpleDelegator
        attr_reader :measure, :duty_expression, :geographical_areas, :national_measurement_units

        delegate :id, to: :duty_expression, prefix: true
        delegate :geographical_area, :geographical_area_id, to: :measure

        def initialize(measure, declarable, geographical_areas = [])
          super(measure)
          @measure = measure
          @duty_expression = Api::V2::Measures::DutyExpressionPresenter.new(measure, declarable)
          @geographical_areas = geographical_areas
          @national_measurement_units = declarable.national_measurement_unit_set
                                                  &.national_measurement_unit_set_units
                                                  &.select(&:present?)
                                                  &.select { |nmu| nmu.level > 1 } || []
        end

        def excise
          measure.excise?
        end

        def vat
          measure.vat?
        end

        def additional_code
          measure.export_refund_nomenclature || measure.additional_code
        end

        def additional_code_id
          measure.export_refund_nomenclature_sid || measure.additional_code_sid
        end

        def measure_condition_ids
          measure.measure_conditions.pluck(:measure_condition_sid)
        end

        def measure_component_ids
          measure.measure_components.map { |component| component.pk.join('-') }
        end

        def national_measurement_unit_ids
          national_measurement_units.map { |unit| unit.pk.join('-') }
        end

        def excluded_geographical_area_ids
          measure.excluded_geographical_areas.pluck(:geographical_area_id)
        end

        def footnote_ids
          measure.footnotes&.map(&:code)
        end

        def legal_act_ids
          measure.legal_acts.map(&:regulation_id)
        end

        # def legal_acts
        #   measure.legal_acts.map do |legal_act|
        #     Api::V2::Measures::MeasureLegalActPresenter.new legal_act, @measure
        #   end
        # end

        def order_number_id
          measure.order_number&.quota_order_number_id
        end

        def excluded_countries
          measure.excluded_geographical_areas + measure_type_exclusions
        end

        def excluded_country_ids
          excluded_countries.map(&:id)
        end

      private

        def measure_type_exclusions
          @measure_type_exclusions ||= MeasureTypeExclusion.find_geographical_areas(
            measure.measure_type_id,
            measure.geographical_area_id,
          )
        end
      end
    end
  end
end
