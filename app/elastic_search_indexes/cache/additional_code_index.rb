module Cache
  class AdditionalCodeIndex < ::Cache::CacheIndex
    EXCLUDED_TYPES = %w[6 7 9 D F P].freeze

    def dataset
      current_sids = Measure
        .actual
        .with_generating_regulation
        .distinct(:additional_code_id, :additional_code_type_id)
        .select(:additional_code_sid, :additional_code_id, :additional_code_type_id)
        .exclude(additional_code_sid: nil)
        .exclude(additional_code_type_id: EXCLUDED_TYPES)
        .exclude(goods_nomenclature_sid: nil)
        .exclude(goods_nomenclature_item_id: nil)
        .pluck(:additional_code_sid)

      super.where(additional_code_sid: current_sids)
    end

    def definition
      {
        mappings: {
          dynamic: false,
          properties: {
            additional_code: { type: 'keyword' },
            additional_code_type_id: { type: 'keyword' },
            description: { type: 'text', analyzer: 'snowball' },
            validity_start_date: { type: 'date', format: 'date_optional_time' },
            validity_end_date: { type: 'date', format: 'date_optional_time' },
          },
        },
      }
    end

    def eager_load
      eager_load_measures.merge(additional_code_descriptions: {})
    end
  end
end
