module Api
  module V2
    class MeasureSerializer < Api::V2::BaseMeasureSerializer
      attribute :excise, &:excise?
      attribute :vat, &:vat?

      attribute :effective_start_date do |measure, _opts|
        measure.validity_start_date.presence || measure.generating_regulation.validity_start_date
      end

      attribute :effective_end_date do |measure, _opts|
        measure&.validity_end_date.presence || measure.generating_regulation&.validity_end_date
      end

      has_one :goods_nomenclature,
              serializer: Api::V2::Shared::GoodsNomenclatureSerializer.serializer_proc

      has_many :excluded_geographical_areas, serializer: Api::V2::GeographicalAreaSerializer
      has_one :additional_code, serializer: Api::V2::AdditionalCodeSerializer

      has_one :measure_generating_legal_act, serializer: Api::V2::Measures::MeasureLegalActSerializer
      has_one :justification_legal_act, serializer: Api::V2::Measures::MeasureLegalActSerializer
    end
  end
end
