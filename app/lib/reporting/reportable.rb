module Reporting
  module Reportable
    extend ActiveSupport::Concern

    module SharedMethods
      include Reporting::ReportLogging

      def mem
        @mem ||= GetProcessMem.new
      end

      def baseline
        @baseline ||= mem.mb
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
    end

    include SharedMethods

    class_methods do
      include SharedMethods
    end
  end
end
