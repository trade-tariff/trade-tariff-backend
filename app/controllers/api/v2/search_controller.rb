module Api
  module V2
    class SearchController < ApiController
      MATCH_TYPES = %i[goods_nomenclature_match reference_match].freeze
      LEVELS = %w[sections chapters headings commodities].freeze

      no_caching

      def search
        request_id = params[:request_id] || SecureRandom.uuid
        search_start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        ::Search::Instrumentation.search_started(request_id:, query: params[:q], search_type: 'classic')

        results = SearchService.new(Api::V2::SearchSerializationService.new, params).to_json

        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - search_start_time
        ::Search::Instrumentation.search_completed(
          request_id:,
          search_type: 'classic',
          total_duration_ms: (duration * 1000).round(2),
          **classic_result_metrics(results),
        )

        render json: results
      end

      def suggestions
        results = Api::V2::SearchSuggestionSerializer.new(matching_suggestions).serializable_hash
        render json: results
      end

      private

      def classic_result_metrics(results)
        return { result_count: 0 } unless results.is_a?(Hash) && results[:data].is_a?(Hash)

        attributes = results[:data][:attributes]
        results_type = results[:data][:type]

        {
          result_count: classic_result_count(attributes, results_type),
          results_type: results_type,
          max_score: classic_max_score(attributes),
        }
      end

      def classic_result_count(attributes, results_type)
        return 1 if results_type == :exact_search

        MATCH_TYPES.product(LEVELS).sum do |match, level|
          attributes&.dig(match)&.dig(level)&.size || 0
        end
      end

      def classic_max_score(attributes)
        MATCH_TYPES.product(LEVELS).map { |match, level|
          attributes&.dig(match)&.dig(level)&.first&.dig('_score') || 0
        }.max
      end

      def matching_suggestions
        if params[:q].present? && !SearchService::RogueSearchService.call(params[:q])
          return SearchSuggestion.fuzzy_search(params[:q])
        end

        []
      end
    end
  end
end
