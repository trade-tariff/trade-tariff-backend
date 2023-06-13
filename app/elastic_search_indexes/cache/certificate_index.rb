module Cache
  class CertificateIndex < ::Cache::CacheIndex
    def definition
      {
        mappings: {
          dynamic: false,
          properties: {
            certificate_code: { type: 'keyword' },
            certificate_type_code: { type: 'keyword' },
            description: { type: 'text', analyzer: 'snowball' },
            validity_start_date: { type: 'date', format: 'date_optional_time' },
            validity_end_date: { type: 'date', format: 'date_optional_time' },
            guidance_cds: { enabled: false },
            guidance_chief: { enabled: false },
          },
        },
      }
    end

    def eager_load
      eager_load_measures.merge(certificate_descriptions: {})
    end
  end
end
