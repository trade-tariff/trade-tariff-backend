module Api
  module Internal
    class QueuedSearchesController < InternalController
      include QueryProcessing

      def create
        search = QueuedSearch.create(params: search_params.to_h, context: search_context)
        unless QueuedSearchWorker.perform_async(search.id)
          search.delete
          return unavailable
        end

        render json: { id: search.id, status: 'queued' }, status: :accepted
      rescue RedisClient::Error
        unavailable
      end

      def show
        payload = QueuedSearch.new(params[:id]).payload
        return head :not_found unless payload

        render json: payload.slice('id', 'status', 'created_at', 'updated_at', 'result', 'response_status')
      rescue RedisClient::Error
        unavailable
      end

    private

      def search_params
        params.permit(:q, :as_of, :request_id, :expanded_query, :skip_question, answers: %i[question answer options])
      end

      def search_context
        TradeTariffRequest.attributes.slice(:request_id, :request_source, :client_id, :experiment)
          .merge(as_of: actual_date.iso8601, search_as_of: parse_date(params[:as_of]).iso8601)
      end

      def unavailable
        render json: { errors: [{ title: 'Queued search is temporarily unavailable' }] }, status: :service_unavailable
      end
    end
  end
end
