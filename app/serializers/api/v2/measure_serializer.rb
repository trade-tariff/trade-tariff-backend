module Api
  module V2
    class MeasureSerializer
      include JSONAPI::Serializer

      set_type :measure

      set_id :measure_sid

      attributes :origin,
                 :import,
                 :export

      attribute :excise, &:excise?
      attribute :vat, &:vat?

      attribute :effective_start_date do |measure, opts|
        measure.validity_start_date.presence || measure.generating_regulation.validity_start_date
      end

      attribute :effective_end_date do |measure, opts|
        measure.validity_end_date.presence || measure.generating_regulation.validity_end_date
      end

      has_one :goods_nomenclature, serializer: proc { |record, _params|
                                                 if record && record.respond_to?(:goods_nomenclature_class)
                                                   "Api::V2::Shared::#{record.goods_nomenclature_class}Serializer".constantize
                                                 else
                                                   Api::V2::Shared::GoodsNomenclatureSerializer
                                                 end
                                               }


      has_one :duty_expression, serializer: Api::V2::Measures::DutyExpressionSerializer
      has_one :measure_type, serializer: Api::V2::Measures::MeasureTypeSerializer
      has_many :legal_acts, serializer: Api::V2::Measures::MeasureLegalActSerializer
      has_many :measure_conditions, serializer: Api::V2::Measures::MeasureConditionSerializer
      has_many :measure_components, serializer: Api::V2::Measures::MeasureComponentSerializer
      has_one :geographical_area, serializer: Api::V2::Measures::GeographicalAreaSerializer
      has_many :excluded_geographical_areas, serializer: Api::V2::GeographicalAreaSerializer
      has_many :footnotes, serializer: Api::V2::Measures::FootnoteSerializer
      has_one :additional_code, serializer: Api::V2::AdditionalCodeSerializer
      has_one :order_number, serializer: Api::V2::Quotas::OrderNumber::QuotaOrderNumberSerializer
    end
  end
end
