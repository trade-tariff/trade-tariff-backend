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
      {
        certificate_descriptions: {},
        appendix_5a: {},
        measures: [
          :base_regulation,
          :modification_regulation,
          {
            goods_nomenclature: %i[goods_nomenclature_descriptions
                                   ns_children
                                   goods_nomenclature_indents],
            geographical_area: %i[geographical_area_descriptions],
          },
        ],
      }
    end
  end
end
