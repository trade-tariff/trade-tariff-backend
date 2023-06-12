module Cache
  class AdditionalCodeSerializer
    include ::Cache::SearchCacheMethods

    attr_reader :additional_code

    def initialize(additional_code, hidden_codes)
      @additional_code = additional_code
      @hidden_codes = hidden_codes
    end

    def as_json
      {
        additional_code_sid: additional_code.additional_code_sid,
        code: additional_code.code,
        additional_code_type_id: additional_code.additional_code_type_id,
        additional_code: additional_code.additional_code,
        description: additional_code.description,
        formatted_description: additional_code.formatted_description,
        validity_start_date: additional_code.validity_start_date,
        validity_end_date: additional_code.validity_end_date,
        measure_ids: measures.map(&:measure_sid),
        measures: serialized_measures,
      }
    end

    private

    def serialized_measures
      measures.map do |measure|
        {
          id: measure.measure_sid,
          measure_sid: measure.measure_sid,
          validity_start_date: measure.validity_start_date,
          validity_end_date: measure.validity_end_date,
          goods_nomenclature_item_id: measure.goods_nomenclature_item_id,
          goods_nomenclature_sid: measure.goods_nomenclature_sid,
          goods_nomenclature_id: measure.goods_nomenclature_sid,
          goods_nomenclature: goods_nomenclature_attributes(measure.goods_nomenclature),
          geographical_area_id: measure.geographical_area_id,
          geographical_area: geographical_area_attributes(measure.geographical_area),
        }
      end
    end

    def measures
      @measures ||= additional_code.measures.select do |measure|
        measure.generating_regulation && measure.goods_nomenclature &&
          @hidden_codes.exclude?(measure.goods_nomenclature_item_id)
      end
    end
  end
end
