module Reporting
  module Reportable
    extend ActiveSupport::Concern

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

      Rails.logger.info "[MEMORY] #{name.ljust(30)} → " \
                        "Peak: #{peak_during.round(2)} MB | " \
                        "Delta: +#{delta.round(2)} MB | " \
                        "Growth from prev: +#{(after - before).round(2)} MB"

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
  end
end
