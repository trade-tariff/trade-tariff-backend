module Api
  module Beta
    class SearchController < ApiController
      DEFAULT_INCLUDES = [
        'hits.ancestors',
        :search_query_parser_result,
        :heading_statistics,
        :chapter_statistics,
        :guide,
        'facet_filter_statistics.facet_classification_statistics',
      ].freeze

      def index
        render json: serialized_result
      end

      private

      def serialized_result
        Api::Beta::SearchResultSerializer.new(
          search_result,
          include: includes,
          meta:,
        ).serializable_hash
      end

      def meta
        frontend_url = search_result.redirect? ? frontend_url_for(search_result.short_code) : nil

        { redirect: !!search_result.redirect?, redirect_to: frontend_url }
      end

      def search_result
        @search_result ||= Beta::SearchService.new(search_query, search_filters).call
      end

      def search_query
        params[:q]
      end

      def search_filters
        (params[:filter].try(:permit, *all_filters) || {}).to_h
      end

      def frontend_url_for(short_code)
        resource_path = case short_code.length
                        when 2
                          '/chapters/:id'
                        when 4
                          '/headings/:id'
                        when 10
                          '/commodities/:id'
                        else
                          short_code = short_code.first(4)
                          '/headings/:id'
                        end

        resource_path.prepend('/xi/') if TradeTariffBackend.xi?

        resource_path = resource_path.sub(':id', short_code)

        URI.join(TradeTariffBackend.frontend_host, resource_path).to_s
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
    end
  end
end
