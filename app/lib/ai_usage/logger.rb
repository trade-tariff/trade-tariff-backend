require 'active_support/log_subscriber'

module AiUsage
  class Logger < ActiveSupport::LogSubscriber
    %w[api_call_completed embedding_api_call_completed].each do |event_name|
      define_method(event_name) { |event| info log_entry(base_payload(event_name, event)) }
    end

    %w[api_call_failed embedding_api_call_failed].each do |event_name|
      define_method(event_name) { |event| error log_entry(error_payload(event_name, event)) }
    end

  private

    def error_payload(event_name, event)
      base_payload(event_name, event).merge(
        error_class: event.payload[:error_class],
        error_message: event.payload[:error_message],
      )
    end

    def base_payload(event_name, event)
      data = {
        event: event_name,
        event_kind: event.payload[:event_kind],
        batch_size: event.payload[:batch_size],
        model: event.payload[:model],
        duration_ms: event.payload[:duration_ms],
      }
      add_ai_usage_fields!(data, event)
      data
    end

    def log_entry(data)
      data.merge(service: 'ai_usage', timestamp: Time.current.iso8601).to_json
    end

    def add_ai_usage_fields!(data, event)
      AiUsage.add_log_fields!(data, event)
    end
  end
end

AiUsage::Logger.attach_to :ai_usage unless Rails.env.test?
