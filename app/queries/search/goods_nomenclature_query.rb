module Search
  class GoodsNomenclatureQuery
    DEFAULT_SIZE = 30

    attr_reader :query_string, :date, :expanded_query, :pos_search, :size

    class << self
      def tagger
        @tagger ||= EngTagger.new
      end
    end

    def initialize(query_string, date, expanded_query: nil, pos_search: true, size: DEFAULT_SIZE)
      @query_string = query_string
      @date = date
      @expanded_query = expanded_query
      @pos_search = pos_search
      @size = size
    end

    def query
      {
        index: index.name,
        body: {
          query: {
            bool: {
              must: [
                hidden_goods_nomenclature_filter,
                multi_match_clause,
                validity_date_filter,
              ],
            },
          },
          size: size,
        },
      }
    end

    private

    def index
      @index ||= GoodsNomenclatureIndex.new
    end

    def multi_match_clause
      words = query_string.split
      return single_word_clause if words.size == 1
      return single_word_clause unless pos_search

      pos_aware_clause
    end

    def single_word_clause
      {
        multi_match: {
          query: sanitized_expanded_query || query_string,
          fields: search_fields,
          type: 'best_fields',
        },
      }
    end

    def pos_aware_clause
      tagged = tag_words(query_string)
      nouns, modifiers = tagged.partition { |_word, tag| noun_tag?(tag) }

      if nouns.empty?
        nouns = tagged
        modifiers = []
      end

      clause = { bool: {} }

      clause[:bool][:must] = nouns.map do |word, _|
        { multi_match: { query: word, fields: search_fields, type: 'best_fields' } }
      end

      should_clauses = modifiers.map do |word, _|
        { multi_match: { query: word, fields: search_fields, type: 'best_fields' } }
      end

      if sanitized_expanded_query.present? && sanitized_expanded_query != query_string
        should_clauses << {
          multi_match: { query: sanitized_expanded_query, fields: search_fields, type: 'best_fields' },
        }
      end

      clause[:bool][:should] = should_clauses if should_clauses.any?

      clause
    end

    def tag_words(text)
      self.class.tagger.get_readable(text).split.map do |token|
        word, tag = token.split('/')
        [word, tag&.downcase]
      end
    end

    def noun_tag?(tag)
      tag&.start_with?('nn') # nn, nns, nnp, nnps
    end

    def sanitized_expanded_query
      return nil if expanded_query.blank?

      expanded_query.gsub(/\b(OR|AND)\b/, ' ').squeeze(' ').strip.presence
    end

    def search_fields
      fields = %w[
        search_references^5
        description^3
        ancestor_descriptions
      ]

      if SearchLabels.enabled?
        fields += %w[
          labels.known_brands^2
          labels.colloquial_terms^2
          labels.synonyms^1.5
          labels.description
        ]
      end

      fields
    end

    def hidden_goods_nomenclature_filter
      {
        bool: {
          must_not: {
            terms: {
              goods_nomenclature_item_id: HiddenGoodsNomenclature.codes,
            },
          },
        },
      }
    end

    def validity_date_filter
      {
        bool: {
          should: [
            {
              bool: {
                must: [
                  { range: { validity_start_date: { lte: date } } },
                  { range: { validity_end_date: { gte: date } } },
                ],
              },
            },
            {
              bool: {
                must: [
                  { range: { validity_start_date: { lte: date } } },
                  { bool: { must_not: { exists: { field: 'validity_end_date' } } } },
                ],
              },
            },
            {
              bool: {
                must: [
                  { bool: { must_not: { exists: { field: 'validity_start_date' } } } },
                  { bool: { must_not: { exists: { field: 'validity_end_date' } } } },
                ],
              },
            },
          ],
        },
      }
    end
  end
end
