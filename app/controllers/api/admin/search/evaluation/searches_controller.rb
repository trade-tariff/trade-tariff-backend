module Api
  module Admin
    module Search
      module Evaluation
        class SearchesController < AdminController
          # Queues the search on EvaluationQueuedSearchWorker's dedicated :evaluation queue
          # and returns immediately, instead of calling SearchService inline (AI-1438) --
          # evaluation searches no longer hold a Puma thread for the search's full duration,
          # the way real user searches already avoid via QueuedSearchesController.
          def create
            overrides = configuration_overrides
            EvaluationConfiguration::AllowlistValidator.call(overrides)

            search = QueuedSearch.create(
              params: search_params.to_h.merge(configuration_overrides: overrides, search_type: 'evaluation'),
              context: search_context,
            )
            unless EvaluationQueuedSearchWorker.perform_async(search.id)
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

          def search_context
            TradeTariffRequest.attributes.slice(:request_id, :request_source, :client_id, :experiment)
              .merge(as_of: actual_date.iso8601)
          end

          def unavailable
            render json: { errors: [{ title: 'Queued search is temporarily unavailable' }] }, status: :service_unavailable
          end

          def configuration_overrides
            params.permit(configuration_overrides: {})[:configuration_overrides].to_h
          end

          def search_params
            params.permit(:q, :as_of, :request_id, :expanded_query, :skip_question, answers: %i[question answer options])
          end
        end
      end
    end
  end
end
