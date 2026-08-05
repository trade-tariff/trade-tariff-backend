module Api
  module V2
    class SearchController < ApiController
      MATCH_TYPES = %i[goods_nomenclature_match reference_match].freeze
      LEVELS = %w[sections chapters headings commodities].freeze
      NAMED_LEVEL_COUNT_KEYS = {
        'chapters' => :chapter_result_count,
        'headings' => :heading_result_count,
        'commodities' => :commodity_result_count,
      }.freeze
      OTHER_LEVELS = (LEVELS - NAMED_LEVEL_COUNT_KEYS.keys).freeze
      EMPTY_LEVEL_COUNTS = {
        chapter_result_count: 0,
        heading_result_count: 0,
        commodity_result_count: 0,
        other_result_count: 0,
      }.freeze

      no_caching

      def search
        request_id = TradeTariffRequest.request_id.presence || SecureRandom.uuid

        results = ::Search::Instrumentation.search(request_id:, query: params[:q], search_type: 'classic') do
          res = SearchService.new(Api::V2::SearchSerializationService.new, params).to_json
          [res, classic_result_metrics(res)]
        end

        render json: results
      end

      def suggestions
        results = Api::V2::SearchSuggestionSerializer.new(matching_suggestions).serializable_hash
        render json: results
      end

    private

      def classic_result_metrics(results)
        return { result_count: 0, **EMPTY_LEVEL_COUNTS } unless results.is_a?(Hash) && results[:data].is_a?(Hash)

        attributes = results[:data][:attributes]
        results_type = results[:data][:type]
        level_counts = classic_level_counts(attributes, results_type)

        {
          result_count: classic_result_count(level_counts, results_type),
          **level_counts,
          results_type: results_type,
          max_score: classic_max_score(attributes, results_type),
        }
      end

      def classic_result_count(level_counts, results_type)
        return 1 if results_type == :exact_search

        level_counts.values.sum
      end

      def classic_level_counts(attributes, results_type)
        return classic_exact_level_counts(attributes) if results_type == :exact_search

        named = NAMED_LEVEL_COUNT_KEYS.each_with_object({}) do |(level, key), memo|
          memo[key] = classic_level_result_count(attributes, level)
        end

        named.merge(
          # Sections and any future non-chapter/heading/commodity groups listed in LEVELS.
          other_result_count: OTHER_LEVELS.sum { |level| classic_level_result_count(attributes, level) },
        )
      end

      def classic_level_result_count(attributes, level)
        MATCH_TYPES.sum do |match|
          attributes&.dig(match, level)&.size || 0
        end
      end

      def classic_exact_level_counts(attributes)
        endpoint = (attributes&.dig(:entry, :endpoint) || attributes&.dig('entry', 'endpoint')).to_s
        key =
          case endpoint
          when 'chapters' then :chapter_result_count
          when 'headings' then :heading_result_count
          when 'commodities', 'subheadings' then :commodity_result_count
          else :other_result_count
          end

        EMPTY_LEVEL_COUNTS.merge(key => 1)
      end

      def classic_max_score(attributes, results_type)
        return 0 if results_type == :exact_search

        max = 0
        MATCH_TYPES.each do |match|
          LEVELS.each do |level|
            score = attributes&.dig(match, level)&.first&.dig('_score') || 0
            max = score if score > max
          end
        end
        max
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
