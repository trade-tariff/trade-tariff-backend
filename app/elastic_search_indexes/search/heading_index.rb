module Search
  class HeadingIndex < ::SearchIndex
    def goods_nomenclature?
      true
    end

    def definition
      {
        mappings: {
          properties: {
            id: {type: 'long'},
            chapter: {
              dynamic: true,
              properties: {
                description: {type: 'text'},
                validity_start_date: {type: 'date', format: 'date_optional_time'},
                producline_suffix: {type: 'keyword'},
                goods_nomenclature_sid: {type: 'long'},
                goods_nomenclature_item_id: {type: 'keyword'}
              }
            },
            validity_end_date: {type: 'date', format: 'date_optional_time'},
            number_indents: {type: 'long'},
            description: {type: 'text', analyzer: 'snowball'},
            validity_start_date: {type: 'date', format: 'date_optional_time'},
            producline_suffix: {type: 'keyword'},
            goods_nomenclature_item_id: {type: 'keyword'},
            section: {
              dynamic: true,
              properties: {
                position: {type: 'long'},
                title: {type: 'text'},
                numeral: {type: 'keyword'}
              }
            }
          }
        }
      }
    end
  end
end
