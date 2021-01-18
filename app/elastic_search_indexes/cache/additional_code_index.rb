module Cache
  class AdditionalCodeIndex < ::Cache::CacheIndex
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
          }
        }
      }
    end
  end
end
