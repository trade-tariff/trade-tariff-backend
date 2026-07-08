module TimedInstrumentation
module_function

  def call(instrumenter:, started_event:, completed_event:, failed_event:, payload:, completed_payload: nil, failed_payload: nil)
    instrumenter.call(started_event, payload)

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = yield
    duration_ms = duration_since(start_time)

    instrumenter.call(completed_event, payload.merge(duration_ms:, **completed_payload_for(completed_payload, result)))

    result
  rescue StandardError => e
    instrumenter.call(
      failed_event,
      payload.merge(
        error_class: e.class.name,
        error_message: e.message,
        duration_ms: duration_since(start_time),
        **payload_for(failed_payload, e),
      ),
    )
    raise
  end

  def completed_payload_for(payload, result)
    payload.respond_to?(:call) ? payload.call(result) : payload.to_h
  end

  def payload_for(payload, error)
    payload.respond_to?(:call) ? payload.call(error) : payload.to_h
  end

  def duration_since(start_time)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
  end
end
