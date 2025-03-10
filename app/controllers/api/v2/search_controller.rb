module Api
  module V2
    class SearchController < ApiController
      no_caching

      def search
        results = SearchService.new(Api::V2::SearchSerializationService.new, params).to_json
        log_search_results(params[:q], results)
        render json: results
      end

      def suggestions
        results = if TradeTariffBackend.optimised_search_enabled?
                    ElasticSearch::ElasticSearchService.new(params).to_suggestions
                  else
                    Api::V2::SearchSuggestionSerializer.new(matching_suggestions).serializable_hash
                  end
        log_search_suggestions_results(params[:q], results)
        render json: results
      end

      private

      def matching_suggestions
        if params[:q].present? && !SearchService::RogueSearchService.call(params[:q])
          return SearchSuggestion.fuzzy_search(params[:q])
        end

        []
      end

      def log_search_results(query, results)
        results_type = results[:data][:type]
        attributes = results[:data][:attributes]

        commodity_score = attributes[:goods_nomenclature_match]['commodities'].first&.dig('_score') || 0
        chapter_score = attributes[:goods_nomenclature_match]['chapters'].first&.dig('_score') || 0
        heading_score = attributes[:goods_nomenclature_match]['headings'].first&.dig('_score') || 0
        section_score = attributes[:goods_nomenclature_match]['sections'].first&.dig('_score') || 0

        ref_commodity_score = attributes[:reference_match]['commodities'].first&.dig('_score') || 0
        ref_chapter_score = attributes[:reference_match]['chapters'].first&.dig('_score') || 0
        ref_heading_score = attributes[:reference_match]['headings'].first&.dig('_score') || 0
        ref_section_score = attributes[:reference_match]['sections'].first&.dig('_score') || 0

        # Find the maximum score
        max_score = [
          commodity_score,
          chapter_score,
          heading_score,
          section_score,
          ref_commodity_score,
          ref_chapter_score,
          ref_heading_score,
          ref_section_score,
        ].max

        results_count = attributes[:goods_nomenclature_match]['chapters'].size + attributes[:reference_match]['chapters'].size + attributes[:goods_nomenclature_match]['commodities'].size + attributes[:reference_match]['commodities'].size + attributes[:goods_nomenclature_match]['headings'].size + attributes[:reference_match]['headings'].size + attributes[:goods_nomenclature_match]['sections'].size + attributes[:reference_match]['sections'].size

        results_zero = results_count.zero?
        query_length = query.present? ? query.length : 0
        Rails.logger.info "Search Request : Search Query [#{query}] | Query Length [#{query_length}] | "\
                            "Result Type [#{results_type}] | Top Result Score [#{max_score}] | "\
                            "Result Count [#{results_count}] | Result Zero [#{results_zero}]"
      end

      def log_search_suggestions_results(query, results)
        results_count = results[:data].size
        results_zero = results_count.nil? || results_count.zero?
        query_length = query.present? ? query.length : 0
        Rails.logger.info "Search Suggestion Request : Search Query [#{query}] | Query Length [#{query_length}] | "\
                            "Result Count [#{results_count}] | Result Zero [#{results_zero}]"
      end
    end
  end
end
