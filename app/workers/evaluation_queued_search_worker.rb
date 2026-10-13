class EvaluationQueuedSearchWorker
  include Sidekiq::Worker

  # A dedicated queue, separate from QueuedSearchWorker's :default (AI-1438) -- evaluation
  # search load must never compete with real user searches for Sidekiq capacity, in either
  # direction: a burst of evaluation searches must not delay a real trader's search, and a
  # surge of real traffic must not starve an evaluation run either.
  sidekiq_options queue: :evaluation, retry: false

  # Matches both sources of per-search LLM/embedding usage -- see with_usage_meta below.
  # Moved here unchanged from the synchronous SearchesController#create this worker
  # replaces (AI-1438): AdminApi (this worker) and InternalApi (real trader search) share
  # the same process-wide ActiveSupport::Notifications fanout, so the request_id filter in
  # the collector below still matters here exactly as it did inline in the controller.
  USAGE_EVENT_PATTERN = /\A(?:api_call_completed\.search|embedding_api_call_(?:completed|failed)\.ai_usage)\z/

  def perform(id)
    search = QueuedSearch.new(id)
    payload = search.claim
    perform_search(search, payload) if payload
  end

private

  def perform_search(search, payload)
    result = execute_search(payload)
    response_status = result.is_a?(Hash) && result[:errors] ? 422 : 200
    search.finish(result:, response_status:)
  rescue StandardError
    search.finish(
      result: { errors: [{ status: '500', title: 'Search failed', detail: 'Search is temporarily unavailable' }] },
      response_status: 500,
    )
    raise
  end

  def execute_search(payload)
    context = payload.fetch('context').symbolize_keys
    as_of = context.delete(:as_of)
    params = payload.fetch('params').with_indifferent_access
    # Sidekiq reuses threads across jobs; ActiveSupport::CurrentAttributes#set only
    # overrides the keys given, it does not reset everything else first, so a prior job's
    # TradeTariffRequest state on this thread could otherwise leak into this search.
    context.merge!(search_failures: [], search_type: nil, search_labels_enabled: nil, time_machine_relevant: nil)

    TradeTariffRequest.set(context) do
      TimeMachine.at(as_of) do
        run_search(params)
      end
    end
  end

  def run_search(params)
    service = Api::Internal::SearchService.new(params)

    usage_events = []
    collector = lambda do |_name, _start, _finish, _id, event_payload|
      usage_events << event_payload if event_payload[:request_id] == service.request_id
    end

    result = ActiveSupport::Notifications.subscribed(collector, USAGE_EVENT_PATTERN) { service.call }
    with_usage_meta(result, usage_events)
  end

  def with_usage_meta(result, usage_events)
    return result unless result.is_a?(Hash) && !result[:errors]

    usage = summed_usage(usage_events)
    return result unless usage

    result.merge(meta: (result[:meta] || {}).merge(usage:))
  end

  # usage_events can hold more than one payload for a single search: InteractiveSearchService's
  # duplicate-question-retry path is a second LLM call in its own right, and vector/hybrid
  # retrieval adds a query-embedding call on top of any of that. Sum across all events
  # received, never assume at most one.
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
end
