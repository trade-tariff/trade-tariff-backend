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
        ElasticSearch::Query::SearchSuggestionQuery.new(q, as_of, Search::GoodsNomenclatureIndex.new).query,
      )

      Api::V2::SearchSuggestionSerializer.new(map_search_results(results, q)).serializable_hash
    end

    def map_search_results(response, query)
      response.dig('hits', 'hits')&.map { |hit|
        source = hit['_source']
        selected_field, selected_value, selected_query = extract_highlight(hit['highlight'])

        SearchSuggestion.unrestrict_primary_key
        SearchSuggestion.new.tap do |suggestion|
          suggestion.id = source['id']
          suggestion.value = selected_value || source['goods_nomenclature_item_id']
          suggestion.type = selected_field || 'goods_nomenclature_item_id'
          suggestion.priority = ''
          suggestion.goods_nomenclature_sid = source['id']
          suggestion.goods_nomenclature_class = source['type']
          suggestion[:score] = hit['_score']
          suggestion[:query] = selected_query.presence || query
        end
      }&.compact
    end

    def extract_highlight(highlight)
      return [nil, nil, nil] unless highlight

      highlight.each do |field, texts|
        Array(texts).each do |text|
          if (match = text.match(/<em>(.*?)<\/em>/))
            return [field.split('.').first, text.gsub(/<\/?em>/, ''), match[1]]
          end
        end
      end

      [nil, nil, nil]
    end
  end
end
