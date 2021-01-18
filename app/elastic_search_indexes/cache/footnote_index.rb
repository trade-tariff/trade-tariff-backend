module Cache
  class FootnoteIndex < ::Cache::CacheIndex
    def definition
      {
        mappings: {
          dynamic: false,
          properties: {
            footnote_id: { type: 'keyword' },
            footnote_type_id: { type: 'keyword' },
            description: { type: 'text', analyzer: 'snowball' },
            validity_start_date: { type: 'date', format: 'date_optional_time' },
            validity_end_date: { type: 'date', format: 'date_optional_time' },
          }
        }
      }
    end
  end
end
