module ElasticSearch
  class ElasticSearchService
    # include ActiveModel::Validations
    # include ActiveModel::Conversion
    include CustomRegex

    class EmptyQuery < StandardError
    end

    attr_reader :q, :result, :as_of, :data_serializer
    attr_accessor :resource_id

    delegate :serializable_hash, to: :result

    def initialize(params = {})
      if params.present?
        params.each do |name, value|
          if respond_to?(:"#{name}=")
            send(:"#{name}=", value)
          end
        end
      end
    end

    def as_of=(date)
      date ||= Time.zone.today.to_s
      @as_of = begin
                 Date.parse(date)
               rescue StandardError
                 Time.zone.today
               end
    end

    def q=(term)
      # use `cas_number_regex` to try to find a CAS number, then
      # if search term has no letters extract the digits
      # and perform search with just the digits (i.e., `no_alpha_regex`)
      # otherwise, ignore [ and ] characters to avoid range searches
      @q = if (m = cas_number_regex.match(term.to_s.first(100)))
             m[1]
           elsif cus_number_regex.match?(term) && digit_regex.match?(term)
             term
           elsif no_alpha_regex.match?(term) && digit_regex.match?(term)
             term.scan(/\d+/).join
           elsif no_alpha_regex.match(term) && !digit_regex.match?(term)
             ''
           else
             term.to_s.gsub(ignore_brackets_regex, '')
           end
    end

    def to_suggestions(_config = {})
      if params[:q].present? && !SearchService::RogueSearchService.call(params[:q])
        @result = perform
      else
        @result = []
      end
      @result
    end

    private

    def perform
      result = TradeTariffBackend.search_client.search(
        ElasticSearch::Query::SearchSuggestionQuery.new(q, as_of, Search::GoodsNomenclatureIndex).query
      )

      Api::V2::SearchSuggestionSerializer.new(result).serializable_hash
    end

    # TradeTariffBackend.search_client.search(ElasticSearch::Query::SearchSuggestionQuery.new('cas', Time.zone.today.to_s, Search::GoodsNomenclatureIndex).query)
  end
end
