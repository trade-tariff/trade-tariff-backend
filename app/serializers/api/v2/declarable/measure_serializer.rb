module Api
  module V2
    module Declarable
      class MeasureSerializer < Api::V2::BaseMeasureSerializer
        include JSONAPI::Serializer

        set_type :measure

        set_id :measure_sid

        attributes :id,
                   :effective_start_date,
                   :effective_end_date,
                   :excise,
                   :vat,
                   :reduction_indicator,
                   :meursing,
                   :resolved_duty_expression,
                   :universal_waiver_applies

        has_one :preference_code, serializer: Api::V2::PreferenceCodeSerializer
        has_one :suspending_regulation, key: :suspension_legal_act,
                                        record_type: :suspension_legal_act, serializer: Api::V2::Measures::MeasureSuspensionLegalActSerializer,
                                        if: proc { |measure| !measure.national && measure.suspended? }
        has_many :measure_condition_permutation_groups, serializer: Api::V2::Measures::MeasureConditionPermutationGroupSerializer
        has_many :resolved_measure_components, serializer: Api::V2::Measures::MeasureComponentSerializer

        has_many :national_measurement_units, serializer: Api::V2::Measures::NationalMeasurementUnitSerializer do |_measure, _params|
          []
        end
        has_many :excluded_countries, record_type: :geographical_area, serializer: Api::V2::GeographicalAreaSerializer
        has_one :additional_code, if: proc { |measure| measure.additional_code.present? }, serializer: Api::V2::AdditionalCodeSerializer

        meta do |measure|
          {
            duty_calculator: {
              source: TradeTariffBackend.service,
              scheme_code: measure.scheme_code,
            },
          }
        end
      end
    end
  end
end
