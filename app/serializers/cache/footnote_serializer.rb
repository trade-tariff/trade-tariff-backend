module Cache
  class FootnoteSerializer
    include ::Cache::SearchCacheMethods

    MAX_MEASURE_THRESHOLD = 1000

    attr_reader :footnote

    def initialize(footnote)
      @footnote = footnote
    end

    def as_json
      footnote_attributes = {
        code: footnote.code,
        footnote_type_id: footnote.footnote_type_id,
        footnote_id: footnote.footnote_id,
        description: footnote.description,
        formatted_description: footnote.formatted_description,
        validity_start_date: footnote.validity_start_date,
        validity_end_date: footnote.validity_end_date,
        goods_nomenclature_ids: goods_nomenclatures.map(&:goods_nomenclature_sid),
        goods_nomenclatures: goods_nomenclatures.map do |goods_nomenclature|
          goods_nomenclature_attributes(goods_nomenclature)
        end,
      }

      unless extra_large_measures?
        footnote_attributes[:measure_ids] = measures.map(&:measure_sid)
        footnote_attributes[:measures] = measures.map do |measure|
          {
            id: measure.measure_sid,
            measure_sid: measure.measure_sid,
            validity_start_date: measure.validity_start_date,
            validity_end_date: measure.validity_end_date,
            goods_nomenclature_item_id: measure.goods_nomenclature_item_id,
            goods_nomenclature_sid: measure.goods_nomenclature_sid,
            goods_nomenclature: goods_nomenclature_attributes(measure.goods_nomenclature),
            goods_nomenclature_id: measure.goods_nomenclature_sid,
            geographical_area_id: measure.geographical_area_id,
            geographical_area: geographical_area_attributes(measure.geographical_area),
          }
        end
      end
      footnote_attributes[:extra_large_measures] = extra_large_measures?
      footnote_attributes
    end

    private

    def goods_nomenclatures
      @goods_nomenclatures ||= footnote.goods_nomenclatures.compact.select do |goods_nomenclature|
        HiddenGoodsNomenclature.codes.exclude?(goods_nomenclature.goods_nomenclature_item_id)
      end
    end

    def measures
      @measures ||= footnote
        .measures_dataset
        .with_generating_regulation
        .eager(:goods_nomenclature)
        .exclude(goods_nomenclature_item_id: nil)
        .all
        .select do |measure|
          measure.goods_nomenclature.present? &&
            HiddenGoodsNomenclature.codes.exclude?(measure.goods_nomenclature_item_id)
        end
    end

    def extra_large_measures?
      measures.size >= MAX_MEASURE_THRESHOLD
    end
  end
end
