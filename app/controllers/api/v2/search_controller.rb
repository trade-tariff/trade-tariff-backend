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

        commodity_score = attributes&.dig(:goods_nomenclature_match)&.dig('commodities')&.first&.dig('_score') || 0
        chapter_score = attributes&.dig(:goods_nomenclature_match)&.dig('chapters')&.first&.dig('_score') || 0
        heading_score = attributes&.dig(:goods_nomenclature_match)&.dig('headings')&.first&.dig('_score') || 0
        section_score = attributes&.dig(:goods_nomenclature_match)&.dig('sections')&.first&.dig('_score') || 0

        ref_commodity_score = attributes&.dig(:reference_match)&.dig('commodities')&.first&.dig('_score') || 0
        ref_chapter_score = attributes&.dig(:reference_match)&.dig('chapters')&.first&.dig('_score') || 0
        ref_heading_score = attributes&.dig(:reference_match)&.dig('headings')&.first&.dig('_score') || 0
        ref_section_score = attributes&.dig(:reference_match)&.dig('sections')&.first&.dig('_score') || 0

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

        chapter_count = attributes&.dig(:goods_nomenclature_match)&.dig('chapters')&.size || 0
        ref_chapter_count = attributes&.dig(:reference_match)&.dig('chapters')&.size || 0
        commodity_count = attributes&.dig(:goods_nomenclature_match)&.dig('commodities')&.size || 0
        attributes&.dig(:reference_match)&.dig('commodities')&.size || 0
        heading_count = attributes&.dig(:goods_nomenclature_match)&.dig('headings')&.size || 0
        ref_heading_count = attributes&.dig(:reference_match)&.dig('headings')&.size || 0
        attributes&.dig(:goods_nomenclature_match)&.dig('sections')&.size || 0
        attributes&.dig(:reference_match)&.dig('sections')&.size || 0
        results_count = chapter_count + ref_chapter_count + heading_count + ref_heading_count + commodity_count

        results_zero = results_count.zero?
        query_length = query.present? ? query.length : 0
        Rails.logger.info "Search Request : search_query=#{query}, query_length=#{query_length}, "\
                            "result_type=#{results_type}, top_result_score=#{max_score}, "\
                            "result_count=#{results_count}, result_zero=#{results_zero}"
      end

      def log_search_suggestions_results(query, results)
        results_count = results[:data].size
        results_zero = results_count.nil? || results_count.zero?
        query_length = query.present? ? query.length : 0
        Rails.logger.info "Search Suggestion Request : search_query=#{query}, query_length=#{query_length}, "\
                            "result_count=#{results_count}, result_zero=#{results_zero}"
      end
    end
  end
end
