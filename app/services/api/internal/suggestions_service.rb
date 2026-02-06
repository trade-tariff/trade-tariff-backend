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

        query = ::Search::SearchSuggestionQuery.new(q, as_of, allowed_types: allowed_suggestion_types, size: suggest_results_limit).query
        results = TradeTariffBackend.search_client.search(query)

        suggestions = results.dig('hits', 'hits')&.map { |hit| build_suggestion(hit) }&.compact || []

        SearchSuggestionSerializer.new(suggestions).serializable_hash
      end

      private

      CONFIGURABLE_SUGGESTION_TYPES = {
        'suggest_chemical_names' => ::SearchSuggestion::TYPE_FULL_CHEMICAL_NAME,
        'suggest_chemical_cas' => ::SearchSuggestion::TYPE_FULL_CHEMICAL_CAS,
        'suggest_chemical_cus' => ::SearchSuggestion::TYPE_FULL_CHEMICAL_CUS,
        'suggest_known_brands' => ::SearchSuggestion::TYPE_KNOWN_BRAND,
        'suggest_colloquial_terms' => ::SearchSuggestion::TYPE_COLLOQUIAL_TERM,
        'suggest_synonyms' => ::SearchSuggestion::TYPE_SYNONYM,
      }.freeze

      def suggest_results_limit
        AdminConfiguration.integer_value('suggest_results_limit')
      end

      def allowed_suggestion_types
        types = [
          ::SearchSuggestion::TYPE_SEARCH_REFERENCE,
          ::SearchSuggestion::TYPE_GOODS_NOMENCLATURE,
        ]

        CONFIGURABLE_SUGGESTION_TYPES.each do |config_name, type|
          types << type if AdminConfiguration.enabled?(config_name)
        end

        types
      end

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
