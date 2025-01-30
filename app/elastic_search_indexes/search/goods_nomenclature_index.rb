module Search
  class GoodsNomenclatureIndex
    def initialize(server_namespace = TradeTariffBackend::SearchClient.server_namespace)
      @server_namespace = server_namespace
    end

    def name
      [@server_namespace, type.pluralize, TradeTariffBackend.service].join('-')
    end

    def type
      model_class.to_s.underscore
    end

    def model_class
      name_without_namespace.chomp('Index').constantize
    end

    def name_without_namespace
      self.class.name.split('::').last
    end

    def definition
      {
        mappings: {
          properties: {
            dynamic: false,
            id: { type: 'long' },
            description: { type: 'text', analyzer: 'snowball' },
            description_indexed: { type: 'text', analyzer: 'snowball' },
            goods_nomenclature_item_id: { type: 'keyword' },
            declarable: { enabled: false },
            ancestor_descriptions: { enabled: false },
            validity_end_date: { format: 'date_optional_time', type: 'date' },
            number_indents: { type: 'long' },
            validity_start_date: { type: 'date', format: 'date_optional_time' },
            producline_suffix: { type: 'keyword' },
            search_references: {
              "type": 'nested',
              "properties": {
                title: { type: 'text', analyzer: 'snowball' },
                title_indexed: { type: 'text', analyzer: 'snowball' },
                reference_class: { type: 'keyword' },
              },
            },
            section: {
              dynamic: true,
              properties: {
                position: { type: 'long' },
                title: { type: 'text' },
                numeral: { type: 'keyword' },
              },
            },
            chapter: {
              dynamic: true,
              properties: {
                description: { type: 'text' },
                validity_start_date: { type: 'date', format: 'date_optional_time' },
                producline_suffix: { type: 'keyword' },
                goods_nomenclature_sid: { type: 'long' },
                goods_nomenclature_item_id: { type: 'keyword' },
              },
            },
            heading: {
              dynamic: true,
              properties: {
                validity_end_date: { type: 'date', format: 'date_optional_time' },
                number_indents: { type: 'long' },
                description: { type: 'text' },
                validity_start_date: { type: 'date', format: 'date_optional_time' },
                producline_suffix: { type: 'keyword' },
                goods_nomenclature_sid: { type: 'long' },
                goods_nomenclature_item_id: { type: 'keyword' },
              },
            },
          },
        },
      }
    end

    def eager_load
      {
        goods_nomenclature_indents: [],
        goods_nomenclature_descriptions: [],
        heading: %i[goods_nomenclature_indents goods_nomenclature_descriptions],
        chapter: %i[goods_nomenclature_descriptions guides sections],
      }
    end
  end
end
