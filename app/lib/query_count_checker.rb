class QueryCountChecker
  MESSAGE = 'Excess queries detected'.freeze

  attr_reader :threshold

  def initialize(threshold, raise_exception: !Rails.env.production?)
    @threshold = threshold
    @raise_exception = raise_exception
  end

  def check
    return true unless query_count > threshold

    raise_exception? ? raise_exception! : alert_to_newrelic
  end

  class ExcessQueryCountException < StandardError; end

private

  def raise_exception?
    !!@raise_exception
  end

  def alert_to_newrelic
    NewRelic::Agent.notice_error(message_with_count)

    false
  end

  def raise_exception!
    raise ExcessQueryCountException, message_with_count
  end

  def query_count
    ::SequelRails::Railties::LogSubscriber.count
  end

  def message_with_count
    "#{MESSAGE}: #{query_count} (limit: #{threshold})"
  end
end
