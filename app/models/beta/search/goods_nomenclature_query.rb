module Beta
  module Search
    class GoodsNomenclatureQuery
      attr_writer :nouns, :verbs, :adjectives, :noun_chunks

      def self.build(search_query_parser_result)
        query = new

        query.nouns = search_query_parser_result.nouns
        query.noun_chunks = search_query_parser_result.noun_chunks
        query.verbs = search_query_parser_result.verbs
        query.adjectives = search_query_parser_result.adjectives

        query
      end

      def query
        candidate_query = { query: { bool: {} } }

        candidate_query[:query][:bool][:must] = must_part if must_part.any?
        candidate_query[:query][:bool][:should] = should_part if should_part.any?

        candidate_query
      end

      private

      def must_part
        part = []

        part.concat(noun_part) if nouns.present? || noun_chunks.present?

        part
      end

      def should_part
        part = []

        part.concat(verb_part) if verbs.present?
        part.concat(adjective_part) if adjectives.present?

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
              fields: [
                'search_references^12',
                'chapter_description^10',
                'heading_description^8',
                'description.exact^6',
                'description_indexed^6',
                'goods_nomenclature_item_id',
              ],
            },
          },
          # TODO: Search for a match in the nested ancestors if possible
          # {
          #   nested: {
          #     path: 'ancestors',
          #     query: {
          #       multi_match: {
          #         query: nouns,
          #         fields: [
          #           'description_indexed^6',
          #         ],
          #       },
          #     },
          #   },
          # },
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
              fields: [
                'search_references^12',
                'chapter_description^10',
                'heading_description^8',
                'description.exact^6',
                'description_indexed^6',
                'goods_nomenclature_item_id',
              ],
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
              fields: [
                'search_references^12',
                'chapter_description^10',
                'heading_description^8',
                'description.exact^6',
                'description_indexed^6',
                'goods_nomenclature_item_id',
              ],
            },
          },
        ]
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
    end
  end
end
