module Api
  module Beta
    class SearchController < ApiController
      DEFAULT_INCLUDES = [
        'hits.ancestors',
        :search_query_parser_result,
        :heading_statistics,
        :chapter_statistics,
        :guide,
      ].freeze

      def index
        if search_result.redirect?
          redirect_to frontend_url_for(search_result.short_code)
        else
          render json: serialized_result
        end
      end

      private

      def serialized_result
        Api::Beta::SearchResultSerializer.new(search_result, include: DEFAULT_INCLUDES).serializable_hash
      end

      def search_result
        @search_result ||= Beta::SearchService.new(search_query).call
      end

      def search_query
        params[:q]
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

        resource_path = resource_path.sub(':id', short_code)

        URI.join(TradeTariffBackend.frontend_host, resource_path).to_s
      end
    end
  end
end
