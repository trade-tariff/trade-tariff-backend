module BulkSearch
  class SearchResult
    include ContentAddressableId

    attr_accessor :number_of_digits,
                  :short_code,
                  :score

    def id
      @id ||= "#{short_code}-#{presented_score}"
    end

    def presented_score
      (score.presence || 0).to_f.round(2)
    end

    def self.build(attributes)
      result = new

      result.number_of_digits = attributes[:number_of_digits]
      result.short_code = attributes[:short_code]
      result.score = attributes[:score]

      result
    end
  end
end
