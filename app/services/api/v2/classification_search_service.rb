module Api
  module V2
    class ClassificationSearchService
      include Api::Internal::QueryProcessing

      DEFAULT_LIMIT = 30
      MAX_LIMIT = 50

      def initialize(params = {})
        @params = params
        sanitiser_result = Api::Internal::InputSanitiser.new(params[:q]).call

        if sanitiser_result[:errors]
          @sanitiser_errors = sanitiser_result
          @query = ''
        else
          @query = process_query(sanitiser_result[:query])
        end
      end

      def call
        return @sanitiser_errors if @sanitiser_errors
        return empty_response if @query.blank?

        result = HybridRetrievalService.call(
          query: @query,
          expanded_query: expanded_query,
          as_of: parse_date(@params[:as_of]),
          request_id: request_id,
          limit: limit,
        )

        ClassificationSearchResultSerializer.serialize(
          result.results,
          meta: response_meta(result),
        )
      end

      private

      def empty_response
        {
          data: [],
          meta: {
            request_id: request_id,
            retrieval_method: 'hybrid',
            expanded_query: expanded_query || @query,
            result_count: 0,
            max_score: nil,
          },
        }
      end

      def response_meta(result)
        {
          request_id: request_id,
          retrieval_method: 'hybrid',
          expanded_query: result.expanded_query,
          result_count: result.results.size,
          max_score: result.results.map(&:score).compact.max,
        }
      end

      def expanded_query
        @params[:expanded_query].to_s.strip.presence
      end

      def request_id
        @request_id ||= @params[:request_id].presence || TradeTariffRequest.request_id.presence || SecureRandom.uuid
      end

      def limit
        raw_limit = @params[:limit].presence || DEFAULT_LIMIT
        [[raw_limit.to_i, 1].max, MAX_LIMIT].min
      end
    end
  end
end
