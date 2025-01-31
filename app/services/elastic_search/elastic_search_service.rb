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
      @result = if q.present? && !SearchService::RogueSearchService.call(q)
                  perform
                else
                  []
                end
      @result
    end

    private

    def perform
      results = TradeTariffBackend.search_client.search(
        ElasticSearch::Query::SearchSuggestionQuery.new(q, as_of, Search::GoodsNomenclatureIndex.new).query,
      )

      Api::V2::SearchSuggestionSerializer.new(map_search_results(results, q)).serializable_hash
    end

    def map_search_results(response, query)
      response.dig('hits', 'hits')&.map do |hit|
        source = hit['_source']
        search_references = source['search_references'] || []

        fields = {
          'Description' => source['description'].to_s,
          'Search References' => search_references.map { |ref| ref['title'] }.join(', '),
          'Item Id' => source['goods_nomenclature_item_id'].to_s,
        }

        selected_field, selected_value = fields.find do |_, value|
          value.split.any? { |word| word.downcase.include?(query.downcase) }
        end || fields.first

        SearchSuggestion.unrestrict_primary_key
        suggestion = SearchSuggestion.new(
          id: hit['_id'],
          value: selected_value,
          type: "Goods Nomenclature #{selected_field}",
          priority: '',
          goods_nomenclature_sid: source['id'],
          goods_nomenclature_class: source['type'],
        )

        suggestion[:score] = hit['_score']
        suggestion[:query] = query

        suggestion
      end
    end
  end
end
