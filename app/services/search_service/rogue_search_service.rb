class SearchService
  class RogueSearchService
    ROGUE_TERMS = %w[gif gifts gift].freeze

    attr_reader :query_string

    def self.call(query_string)
      new(query_string).call
    end

    def initialize(query_string)
      @query_string = query_string&.downcase
    end

    def call
      ROGUE_TERMS.include?(query_string)
    end
  end
end
