module TimedInstrumentation
  module_function

  def call(instrumenter:, started_event:, completed_event:, failed_event:, payload:, completed_payload: nil, failed_payload: nil)
    start_time = nil
    instrumenter.call(started_event, payload)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    result = yield
    duration_ms = duration_since(start_time)

    instrumenter.call(
      completed_event,
      payload.merge(**completed_payload_for(completed_payload, result), duration_ms:),
    )

    result
  rescue StandardError => e
    instrumenter.call(
      failed_event,
      payload.merge(
        **payload_for(failed_payload, e),
        error_class: e.class.name,
        duration_ms: duration_since(start_time),
      ),
    )
    raise
  end

  def completed_payload_for(payload, result)
    return {} if payload.nil?

    payload.respond_to?(:call) ? payload.call(result) : payload.to_h
  end

  def payload_for(payload, error)
    return {} if payload.nil?

    payload.respond_to?(:call) ? payload.call(error) : payload.to_h
  end

  def duration_since(start_time)
    return 0.0 if start_time.nil?

    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
  end
end
