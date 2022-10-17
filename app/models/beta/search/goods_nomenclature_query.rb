module Beta
  module Search
    class GoodsNomenclatureQuery
      attr_writer :nouns,
                  :verbs,
                  :adjectives,
                  :noun_chunks,
                  :filters,
                  :numeric

      attr_accessor :original_search_query
      alias_method :short_code, :original_search_query

      include ContentAddressableId

      content_addressable_fields :query

      MULTI_MATCH_FIELDS = [
        'search_references^12',
        'ancestor_1_description_indexed^10', # chapter
        'ancestor_2_description_indexed^8', # heading
        'description_indexed^6',
        'ancestor_3_description_indexed^4',
        'ancestor_4_description_indexed^4',
        'ancestor_5_description_indexed^4',
        'ancestor_6_description_indexed^4',
        'ancestor_7_description_indexed^4',
        'ancestor_8_description_indexed^4',
        'ancestor_9_description_indexed^4',
        'ancestor_10_description_indexed^4',
        'ancestor_11_description_indexed^4',
        'ancestor_12_description_indexed^4',
        'ancestor_13_description_indexed^4',
        'goods_nomenclature_item_id',
      ].freeze

      def self.build(search_query_parser_result, filters = {})
        query = new

        is_numeric = search_query_parser_result.original_search_query.match(/^\d+$/).is_a?(MatchData)

        query.nouns = search_query_parser_result.nouns
        query.noun_chunks = search_query_parser_result.noun_chunks
        query.verbs = search_query_parser_result.verbs
        query.adjectives = search_query_parser_result.adjectives
        query.filters = filters
        query.numeric = is_numeric
        query.original_search_query = search_query_parser_result.original_search_query

        query
      end

      def query
        @query ||= if numeric?
                     goods_nomenclature_item_id_term_query
                   else
                     multi_match_query
                   end
      end

      def goods_nomenclature_item_id
        if original_search_query.length > 10
          original_search_query.first(10)
        else
          padding = 10 - original_search_query.length

          original_search_query + '0' * padding
        end
      end

      def numeric?
        @numeric
      end

      private

      def goods_nomenclature_item_id_term_query
        {
          query: {
            term: {
              goods_nomenclature_item_id: {
                value: goods_nomenclature_item_id,
              },
            },
          },
        }
      end

      def multi_match_query
        candidate_query = { size:, query: { bool: {} } }

        candidate_query[:query][:bool][:filter] = filter_part
        candidate_query[:query][:bool][:must] = must_part if must_part.any?
        candidate_query[:query][:bool][:should] = should_part if should_part.any?

        candidate_query
      end

      def filter_part
        part = { bool: {} }

        part[:bool][:must] = static_and_dynamic_filters
        part[:bool][:must] << declarable_filter

        part
      end

      def must_part
        part = []

        # When there are only should verbs and adjectives coming back from the spacy tokenizer we need to move adjectives and verbs to the must part.
        if nouns.present? || noun_chunks.present?
          part.concat(noun_part)
        else
          part.concat(verb_part) if verbs.present?
          part.concat(adjective_part) if adjectives.present?
        end

        part
      end

      def should_part
        part = []

        # When there are only should verbs and adjectives coming back from the spacy tokenizer we need to move adjectives and verbs to the must part
        if nouns.present? || noun_chunks.present?
          part.concat(verb_part) if verbs.present?
          part.concat(adjective_part) if adjectives.present?
        end

        part
      end

      def noun_part
        [
          {
            multi_match: {
              query: nouns.presence || noun_chunks,
              fuzziness: 0.1,
              prefix_length: 2,
              tie_breaker: 0.3,
              type: 'best_fields',
              fields: MULTI_MATCH_FIELDS,
            },
          },
        ]
      end

      def verb_part
        [
          {
            multi_match: {
              query: verbs,
              fuzziness: 0.1,
              prefix_length: 2,
              tie_breaker: 0.3,
              type: 'best_fields',
              fields: MULTI_MATCH_FIELDS,
            },
          },
        ]
      end

      def adjective_part
        [
          {
            multi_match: {
              query: adjectives,
              fuzziness: 0.1,
              prefix_length: 2,
              tie_breaker: 0.3,
              type: 'best_fields',
              fields: MULTI_MATCH_FIELDS,
            },
          },
        ]
      end

      def filters
        @filters.presence || []
      end

      def nouns
        @nouns.try(:join, ' ').presence || ''
      end

      def noun_chunks
        @noun_chunks.try(:join, ' ').presence || ''
      end

      def verbs
        @verbs.try(:join, ' ') || ''
      end

      def adjectives
        @adjectives.try(:join, ' ') || ''
      end

      def size
        TradeTariffBackend.beta_search_max_hits
      end

      def static_and_dynamic_filters
        Api::Beta::GoodsNomenclatureFilterGeneratorService.new(@filters).call
      end

      def declarable_filter
        { "term": { "declarable": true } }
      end
    end
  end
end
