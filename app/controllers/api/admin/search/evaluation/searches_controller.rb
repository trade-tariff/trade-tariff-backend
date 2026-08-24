module Api
  module Admin
    module Search
      module Evaluation
        class SearchesController < AdminController
          def create
            EvaluationConfiguration::AllowlistValidator.call(configuration_overrides)

            usage_events = []
            collector = ->(_name, _start, _finish, _id, payload) { usage_events << payload }

            result = ActiveSupport::Notifications.subscribed(collector, 'api_call_completed.search') do
              Api::Internal::SearchService.new(search_params.to_h.merge(configuration_overrides:, search_type: 'evaluation')).call
            end

            if result.is_a?(Hash) && result[:errors]
              render json: result, status: :unprocessable_content
            else
              render json: with_usage_meta(result, usage_events)
            end
          end

        private

          def with_usage_meta(result, usage_events)
            usage = summed_usage(usage_events)
            return result unless usage

            result.merge(meta: (result[:meta] || {}).merge(usage:))
          end

          # usage_events usually holds 0 or 1 payloads, but
          # InteractiveSearchService#questions_result can call the model a
          # second time on the duplicate-question-retry path
          # (interactive_search_service.rb:441) — sum across all received,
          # never assume at most one.
          def summed_usage(usage_events)
            return nil if usage_events.empty?

            {
              total_cost_usd: sum_present(usage_events, :total_cost_usd),
              total_tokens: sum_present(usage_events, :total_tokens),
              duration_ms: sum_present(usage_events, :duration_ms),
              pricing_known: usage_events.all? { |event| event[:pricing_known] },
            }
          end

          def sum_present(usage_events, key)
            values = usage_events.filter_map { |event| event[key] }
            values.sum if values.any?
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
