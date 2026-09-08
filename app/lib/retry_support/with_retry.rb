module RetrySupport
  module WithRetry
    def with_retry(max_attempts: nil, retryable_errors: nil, delay_calculator: nil, on_retry: nil, on_exhausted: nil, on_success: nil)
      attempts = 0

      begin
        attempts += 1
        result = yield(attempts)
        on_success&.call(attempt: attempts, max_attempts:, result:)
        result
      rescue *Array(retryable_errors) => e
        if attempts < max_attempts
          delay = delay_calculator.call(attempts, e)
          on_retry&.call(attempt: attempts, max_attempts:, delay:, error: e)
          Kernel.sleep(delay)
          retry
        end

        on_exhausted&.call(attempt: attempts, max_attempts:, error: e)
        raise
      end
    end
  end
end
