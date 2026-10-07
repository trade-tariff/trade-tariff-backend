# Tells the eval app to start processing a run the backend has just created. The eval app's own
# POST /start is already fire-and-forget (it returns immediately and does the real work in a
# background task) and already guards against being called twice on the same run (a second call
# while the first is still in flight gets a 409) — so a short, bounded retry on a transient
# connection failure is safe: the worst case is a harmless 409 on the retry, not a duplicate run.
class EvalAppClient
  include RetrySupport::WithRetry

  class Error < StandardError; end

  MAX_ATTEMPTS = 2
  RETRY_DELAY = 1 # second — this is a same-infrastructure service call, not an LLM request;
  # OpenaiClient's exponential backoff (2s/4s/8s...) is tuned for a much slower, flakier upstream.

  RETRYABLE_ERRORS = [Faraday::TimeoutError, Faraday::ConnectionFailed].freeze

  def self.start_run!(run_id)
    new.start_run!(run_id)
  end

  def start_run!(run_id)
    # Checked up front, not left to whatever Faraday happens to do with a blank URL (an
    # Addressable::URI::InvalidURIError that isn't even a Faraday::Error, so it would escape this
    # method's own rescue below and crash the whole create request with a 500) — and not worth
    # retrying, since a missing env var won't fix itself between attempts. A deployment that
    # forgot to add EVAL_APP_URL to Secrets Manager gets a `failed` run with a message that says
    # exactly what's missing, same as any other EvalAppClient::Error.
    raise Error, 'EVAL_APP_URL is not configured' if TradeTariffBackend.eval_app_url.blank?

    response = with_retry(
      max_attempts: MAX_ATTEMPTS,
      retryable_errors: RETRYABLE_ERRORS,
      delay_calculator: ->(_attempts, _error) { RETRY_DELAY },
    ) { self.class.client.post("api/evaluation/runs/#{run_id}/start") }

    return if [202, 409].include?(response.status)

    raise Error, "eval app returned #{response.status} starting run #{run_id}"
  rescue Faraday::Error => e
    # Catches both a RETRYABLE_ERRORS member re-raised after exhausting retries, and any OTHER
    # Faraday::Error subclass (e.g. Faraday::SSLError) that was never retried at all — with_retry
    # only rescues what's in retryable_errors, so anything else raised inside its block would
    # otherwise escape this method uncaught, and from there escape EvaluationRun.start!'s own
    # trigger_eval_app! (which only rescues EvalAppClient::Error) too, crashing the whole create
    # request with a 500 instead of the graceful "run created, marked failed" outcome this task
    # exists to guarantee.
    raise Error, "could not reach the eval app: #{e.message}"
  end

  def self.client
    @client ||= Faraday.new(url: TradeTariffBackend.eval_app_url, ssl: InternalSsl.options) do |faraday|
      faraday.adapter Faraday.default_adapter
      faraday.headers['Authorization'] = "Bearer #{TradeTariffBackend.eval_app_auth_token}"
      faraday.headers['User-Agent'] = TradeTariffBackend.user_agent
      faraday.options.timeout = TradeTariffBackend.eval_app_timeout
      faraday.options.open_timeout = TradeTariffBackend.eval_app_open_timeout
    end
  end
end
