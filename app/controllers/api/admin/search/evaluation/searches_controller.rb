module Api
  module Admin
    module Search
      module Evaluation
        class SearchesController < AdminController
          # Matches both sources of per-search LLM/embedding usage:
          #   - api_call_completed.search: interactive-search LLM calls
          #     (Search::Instrumentation::ApiEvents#api_call)
          #   - embedding_api_call_completed.ai_usage: the query-embedding call
          #     vector/hybrid retrieval makes (AiUsage::Instrumentation#embedding_api_call,
          #     via VectorRetrievalService) -- without this, an eval run configured for
          #     vector/hybrid retrieval would silently omit its embedding cost from
          #     meta.usage, biasing cost comparisons against exactly the retrieval
          #     strategies most worth benchmarking.
          # A Regexp lets one .subscribed call listen to both: Fanout#subscribe only
          # accepts a String, Regexp, or nil pattern, not an array of patterns.
          USAGE_EVENT_PATTERN = /\A(?:api_call_completed\.search|embedding_api_call_completed\.ai_usage)\z/

          def create
            EvaluationConfiguration::AllowlistValidator.call(configuration_overrides)

            # Built before subscribing so service.request_id (resolved in #initialize) is
            # available to filter the collector below.
            service = Api::Internal::SearchService.new(search_params.to_h.merge(configuration_overrides:, search_type: 'evaluation'))

            usage_events = []
            # ActiveSupport::Notifications.subscribed subscribes on the single, process-wide
            # Fanout notifier for the duration of this block -- it is NOT scoped to this
            # thread or request (activesupport's notifications.rb: `self.notifier =
            # Fanout.new`, and #subscribed just does notifier.subscribe/yield/unsubscribe).
            # AdminApi (this endpoint) and InternalApi (real trader search) run in the same
            # multi-threaded Puma process, so without the request_id filter here, this
            # collector would also pick up cost/token data from any other search completing
            # concurrently in this process -- another eval request, or live trader search --
            # and silently inflate this response's meta.usage.
            collector = lambda do |_name, _start, _finish, _id, payload|
              usage_events << payload if payload[:request_id] == service.request_id
            end

            result = ActiveSupport::Notifications.subscribed(collector, USAGE_EVENT_PATTERN) { service.call }

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

          # usage_events can hold more than one payload for a single request:
          # InteractiveSearchService#questions_result can call the model a second time on
          # the duplicate-question-retry path (interactive_search_service.rb:441), and
          # InteractiveSearch::DuplicateQuestionGuard's own semantic-duplicate check
          # (duplicate_question_guard.rb:115-136) is a separate LLM call in its own right;
          # vector/hybrid retrieval adds a query-embedding call on top of any of that. Sum
          # across all events received, never assume at most one.
          def summed_usage(usage_events)
            return nil if usage_events.empty?

            {
              total_cost_usd: sum_present(usage_events, :total_cost_usd),
              total_tokens: sum_present(usage_events, :total_tokens),
              duration_ms: sum_present(usage_events, :duration_ms),
              provider_calls: usage_events.size,
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
