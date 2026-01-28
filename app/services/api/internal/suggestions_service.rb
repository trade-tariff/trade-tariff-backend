module Api
  module Internal
    class SuggestionsService
      include QueryProcessing

      attr_reader :q, :as_of

      def initialize(params = {})
        @q = process_query(params[:q])
        @as_of = parse_date(params[:as_of])
      end

      def call
        if q.blank? || ::SearchService::RogueSearchService.call(q)
          return { data: [] }
        end

        results = TradeTariffBackend.search_client.search(
          ::Search::SearchSuggestionQuery.new(q, as_of).query,
        )

        suggestions = results.dig('hits', 'hits')&.map { |hit| build_suggestion(hit) }&.compact || []

        SearchSuggestionSerializer.new(suggestions).serializable_hash
      end

      private

      def build_suggestion(hit)
        source = hit['_source']

        ::SearchSuggestion.unrestrict_primary_key
        ::SearchSuggestion.new.tap do |s|
          s.id = source['goods_nomenclature_sid']
          s.value = source['value']
          s.type = source['suggestion_type']
          s.priority = source['priority']
          s.goods_nomenclature_sid = source['goods_nomenclature_sid']
          s.goods_nomenclature_class = source['goods_nomenclature_class']
          s[:score] = hit['_score']
          s[:query] = q
        end
      end
    end
  end
end
