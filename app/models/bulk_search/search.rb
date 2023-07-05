module BulkSearch
  class Search
    include ContentAddressableId

    content_addressable_fields :input_description

    attr_accessor :input_description,
                  :number_of_digits,
                  :search_results

    def self.build(attributes)
      search = new

      search.input_description = attributes[:input_description]
      search.number_of_digits = attributes[:number_of_digits]
      search.search_results = attributes[:search_results].map do |result|
        SearchResult.build(result.symbolize_keys!)
      end

      search
    end

    def no_results!
      self.search_results = [
        SearchResult.build(
          number_of_digits:,
          short_code: '9' * number_of_digits,
          score: 0,
        ),
      ]
    end

    def search_result_ids
      search_results.map(&:id)
    end
  end
end
