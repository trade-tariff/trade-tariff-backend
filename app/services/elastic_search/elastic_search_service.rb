module ElasticSearch
  class ElasticSearchService
    include ActiveModel::Validations
    include ActiveModel::Conversion
    include CustomRegex

    class EmptyQuery < StandardError
    end

    attr_reader :q, :result, :as_of, :data_serializer
    attr_accessor :resource_id

    delegate :serializable_hash, to: :result

    def initialize(params = {})
      @as_of = parse_date(params[:as_of])
      @q = process_query(params[:q])
    end

    def to_suggestions(_config = {})
      if q.present? && !SearchService::RogueSearchService.call(q)
        perform
      else
        []
      end
    end

    private

    def parse_date(date)
      return Time.zone.today if date.blank?

      Date.parse(date)
    rescue StandardError
      Time.zone.today
    end

    def process_query(term)
      return '' if term.blank?

      term = term.to_s.first(100)

      if (m = cas_number_regex.match(term))
        m[1]
      elsif cus_number_regex.match?(term) && digit_regex.match?(term)
        term
      elsif no_alpha_regex.match?(term) && digit_regex.match?(term)
        term.scan(/\d+/).join
      elsif no_alpha_regex.match?(term) && !digit_regex.match?(term)
        ''
      else
        term.gsub(ignore_brackets_regex, '')
      end
    end

    def perform
      results = TradeTariffBackend.search_client.search(
        Search::SearchSuggestionQuery.new(q, as_of).query,
      )

      suggestions = results.dig('hits', 'hits')&.map { |hit|
        source = hit['_source']

        SearchSuggestion.unrestrict_primary_key
        SearchSuggestion.new.tap do |suggestion|
          suggestion.id = source['goods_nomenclature_sid']
          suggestion.value = source['value']
          suggestion.type = source['suggestion_type']
          suggestion.priority = source['priority']
          suggestion.goods_nomenclature_sid = source['goods_nomenclature_sid']
          suggestion.goods_nomenclature_class = source['goods_nomenclature_class']
          suggestion[:score] = hit['_score']
          suggestion[:query] = q
        end
      }&.compact

      Api::V2::SearchSuggestionSerializer.new(suggestions).serializable_hash
    end
  end
end
