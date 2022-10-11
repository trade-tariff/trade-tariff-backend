module Api
  module Beta
    class SearchSynonymMatcherService
      delegate :aggregated_synonyms, to: :class

      AGGREGATED_SYNONYMS_FILE = 'config/aggregated_synonyms/synonyms_all.txt'.freeze
      SYNONYM_RANGE = '[\w, -’]'.freeze
      EXPLICIT_MAPPING_REGEX = /^(?<lhs>#{SYNONYM_RANGE}+) => ?(?<_rhs>#{SYNONYM_RANGE}+)$/

      def initialize(original_search_query)
        @original_search_query = original_search_query
      end

      def call
        aggregated_synonyms.include?(@original_search_query)
      end

      def self.aggregated_synonyms
        @aggregated_synonyms ||= File.readlines(AGGREGATED_SYNONYMS_FILE).each_with_object(Set.new) do |synonym_line, acc|
          next if synonym_line == "\n"

          match = synonym_line.match(EXPLICIT_MAPPING_REGEX)

          synonyms = if match
                       # Explicit synonyms
                       match[:lhs]
                     else
                       # Equivalent synonyms
                       synonym_line
                     end

          synonyms.split(',').map do |synonym|
            acc << synonym.strip
          end
        end
      end
    end
  end
end
