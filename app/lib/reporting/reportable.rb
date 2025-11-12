module Reporting
  module Reportable
    extend ActiveSupport::Concern

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
      ::SequelRails::Railties::LogSubscriber.reset_tables
      start_time = Time.zone.now
      yield if block_given?
    ensure
      end_time = Time.zone.now
      duration = end_time - start_time
      Rails.logger.info("#{label} Total Time: #{duration.round(2)} seconds")
      Rails.logger.info("#{label} SQL Queries: #{::SequelRails::Railties::LogSubscriber.count}, Total SQL Time: #{::SequelRails::Railties::LogSubscriber.runtime.round(2)} ms")
      Rails.logger.info("#{label} SQL Tables: #{::SequelRails::Railties::LogSubscriber.tables_pretty}")
    end
  end
end
