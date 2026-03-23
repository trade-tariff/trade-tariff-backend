module Reporting
  module Reportable
    extend ActiveSupport::Concern

    REPORT_BACKTRACE_LINES = 20

    def mem
      @mem ||= GetProcessMem.new
    end

    def baseline
      @baseline ||= mem.mb
    end

    def baseline=(value)
      @baseline = value
    end

    def profile_mem_report(name)
      mem = GetProcessMem.new

      baseline ||= mem.mb

      before = mem.mb
      gc_start

      yield if block_given?

      gc_start
      after = mem.mb

      peak_during = [after, before].max
      delta = peak_during - baseline

      Rails.logger.info "[MEMORY] #{name.ljust(30)} -> " + "Peak: #{peak_during.round(2)} MB | " + "Delta: +#{delta.round(2)} MB | " + "Growth from prev: +#{(after - before).round(2)} MB"

      self.baseline = peak_during
    end

    def gc_start
      GC.start(full_mark: true, immediate_sweep: true)
    end

    def object(key = object_key)
      bucket.object(key)
    end

    def bucket
      Rails.application.config.reporting_bucket
    end

    delegate :service, to: TradeTariffBackend

    def day
      now.day.to_s.rjust(2, '0')
    end

    def month
      now.month.to_s.rjust(2, '0')
    end

    delegate :year, to: :now

    def now
      Time.zone.today
    end

    def today_object_key
      object_key
    end

    def available_today?
      Reporting.published_exist?(today_object_key)
    end

    def download_link_today
      Reporting.published_link(today_object_key)
    end

    def zip(data, filename)
      buffer = Zip::OutputStream.write_buffer { |out|
        out.put_next_entry(filename)
        out.write data
      }.tap(&:rewind)

      {
        data: buffer.read,
        filename: filename.gsub(File.extname(filename), '.zip'),
        content_type: 'application/zip',
      }
    end

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
      name
    end
  end
end
