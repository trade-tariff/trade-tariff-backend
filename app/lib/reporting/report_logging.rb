module Reporting
  module ReportLogging
    REPORT_BACKTRACE_LINES = 20

    def instrument(label = "#{self.class.name}##{__method__}")
      ::SequelRails::Railties::LogSubscriber.reset_runtime
      ::SequelRails::Railties::LogSubscriber.reset_count
      start_time = Time.zone.now
      yield if block_given?
    ensure
      end_time = Time.zone.now
      duration = end_time - start_time
      Rails.logger.info("#{label} Total Time: #{duration.round(2)} seconds")
      Rails.logger.info("#{label} SQL Queries: #{::SequelRails::Railties::LogSubscriber.count}, Total SQL Time: #{::SequelRails::Railties::LogSubscriber.runtime.round(2)} ms")
    end

    def with_report_logging
      start_time = Time.zone.now
      log_report_event(status: 'start')
      result = yield if block_given?
      log_report_event(
        status: 'ok',
        duration_seconds: (Time.zone.now - start_time).round(2),
      )
      result
    rescue StandardError => e
      log_report_event(
        status: 'error',
        duration_seconds: (Time.zone.now - start_time).round(2),
        error_class: e.class.name,
        error_message: e.message,
      )
      Rails.logger.error(e.backtrace.take(REPORT_BACKTRACE_LINES).join("\n")) if e.backtrace.present?
      raise
    end

    def instrument_report_step(step, **attributes)
      ::SequelRails::Railties::LogSubscriber.reset_runtime
      ::SequelRails::Railties::LogSubscriber.reset_count
      start_time = Time.zone.now

      result = yield if block_given?

      log_report_event(
        step:,
        status: 'ok',
        duration_seconds: (Time.zone.now - start_time).round(2),
        sql_queries: ::SequelRails::Railties::LogSubscriber.count,
        sql_time_ms: ::SequelRails::Railties::LogSubscriber.runtime.round(2),
        **attributes,
      )
      result
    rescue StandardError => e
      log_report_event(
        step:,
        status: 'error',
        duration_seconds: (Time.zone.now - start_time).round(2),
        sql_queries: ::SequelRails::Railties::LogSubscriber.count,
        sql_time_ms: ::SequelRails::Railties::LogSubscriber.runtime.round(2),
        error_class: e.class.name,
        error_message: e.message,
        **attributes,
      )
      raise
    end

    def log_report_metric(metric, value, **attributes)
      log_report_event(metric:, value:, **attributes)
    end

    def log_report_event(**attributes)
      Rails.logger.info(
        "reporting #{report_log_attributes(attributes).map { |key, value| "#{key}=#{value.inspect}" }.join(' ')}",
      )
    end

    def report_log_attributes(attributes = {})
      {
        report: report_name,
        service:,
        object_key: object_key,
      }.merge(attributes.compact)
    end

    def report_name
      respond_to?(:name) ? name : self.class.name
    end
  end
end
