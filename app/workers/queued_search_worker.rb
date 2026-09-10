class QueuedSearchWorker
  include Sidekiq::Worker

  # A failed search is terminal for the poller. Retrying requires a new submission,
  # rather than letting expensive searches accumulate Sidekiq retries.
  sidekiq_options queue: :default, retry: false

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
    params[:as_of] = context.delete(:search_as_of) || as_of
    context.merge!(search_failures: [], search_type: nil, search_labels_enabled: nil, time_machine_relevant: nil)

    TradeTariffRequest.set(context) do
      TimeMachine.at(as_of) do
        Api::Internal::SearchService.new(params).call
      end
    end
  end
end
