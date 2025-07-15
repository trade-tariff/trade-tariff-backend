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

    def object_key_prefix(tariff = service)
      "#{tariff}/reporting/#{year}/#{month}/#{day}"
    end

    def object_key_suffix(tariff = service)
      "#{tariff}_#{now.strftime('%Y_%m_%d')}"
    end

    def log_query_count
      Rails.logger.debug("Query count: #{::SequelRails::Railties::LogSubscriber.count}")
    end
  end
end
