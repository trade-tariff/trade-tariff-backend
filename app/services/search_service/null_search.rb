class SearchService
  class NullSearch < BaseSearch
    def initialize(query_string)
      super
      @results = BLANK_RESULT
    end

    def serializable_hash
      {
        type: 'null_match',
      }.merge(results)
    end
  end
end
