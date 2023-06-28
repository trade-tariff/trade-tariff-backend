module Api
  module Beta
    class SearchController < ApiController
      include NoCaching

      DEFAULT_INCLUDES = [
        'hits.ancestors',
        :search_query_parser_result,
        :heading_statistics,
        :chapter_statistics,
        :guide,
        :intercept_message,
        'facet_filter_statistics.facet_classification_statistics',
        :direct_hit,
      ].freeze

      def index
        render json: serialized_result
      end

      private

      def serialized_result
        Api::Beta::SearchResultSerializer.new(search_result, include: includes).serializable_hash
      end

      def search_result
        @search_result ||= Beta::SearchService.new(search_query, search_params).call
      end

      def search_query
        params[:q]
      end

      def search_params
        { spell:, filters:, resource_id: }
      end

      def filters
        (params[:filter].try(:permit, *all_filters) || {}).to_h
      end

      def all_filters
        TradeTariffBackend.search_facet_classifier_configuration.all_filters
      end

      def includes
        if TradeTariffBackend.beta_search_debug?
          [:goods_nomenclature_query].concat(DEFAULT_INCLUDES)
        else
          DEFAULT_INCLUDES
        end
      end

      def spell
        params[:spell].presence || '1'
      end

      def resource_id
        params[:resource_id].presence
      end
    end
  end
end
