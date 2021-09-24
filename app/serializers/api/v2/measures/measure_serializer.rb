module Api
  module V2
    module Measures
      class MeasureSerializer
        include JSONAPI::Serializer

        set_type :measure

        set_id :measure_sid

        attributes :id, :origin, :effective_start_date, :effective_end_date, :import,
                   :excise, :vat, :reduction_indicator

        has_one :duty_expression, serializer: Api::V2::Measures::DutyExpressionSerializer, lazy_load_data: true
        has_one :measure_type, serializer: Api::V2::Measures::MeasureTypeSerializer, lazy_load_data: true
        has_many :legal_acts, serializer: Api::V2::Measures::MeasureLegalActSerializer, lazy_load_data: true
        has_one :suspending_regulation, key: :suspension_legal_act,
                                        record_type: :suspension_legal_act, serializer: Api::V2::Measures::MeasureSuspensionLegalActSerializer,
                                        if: proc { |measure| !measure.national && measure.suspended? }, lazy_load_data: true
        has_many :measure_conditions, serializer: Api::V2::Measures::MeasureConditionSerializer, lazy_load_data: true
        has_many :measure_components, serializer: Api::V2::Measures::MeasureComponentSerializer, lazy_load_data: true
        has_many :national_measurement_units, serializer: Api::V2::Measures::NationalMeasurementUnitSerializer, lazy_load_data: true
        has_one :geographical_area, serializer: Api::V2::Measures::GeographicalAreaSerializer, lazy_load_data: true
        has_many :excluded_countries, record_type: :geographical_area, serializer: Api::V2::GeographicalAreaSerializer, lazy_load_data: true
        has_many :footnotes, serializer: Api::V2::Measures::FootnoteSerializer, lazy_load_data: true
        has_one :additional_code, if: proc { |measure| measure.additional_code.present? }, serializer: Api::V2::AdditionalCodeSerializer, lazy_load_data: true
        has_one :order_number, serializer: Api::V2::Quotas::OrderNumber::QuotaOrderNumberSerializer, lazy_load_data: true

        meta do |_measure|
          {
            duty_calculator: {
              source: TradeTariffBackend.service,
            },
          }
        end
      end
    end
  end
end
