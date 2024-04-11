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

    def day(days_ago = 0)
      now(days_ago).day.to_s.rjust(2, '0')
    end

    def month(days_ago = 0)
      now(days_ago).month.to_s.rjust(2, '0')
    end

    def year(days_ago = 0)
      now(days_ago).year.to_s.rjust(4, '0')
    end

    def now(days_ago = 0)
      Time.zone.today - days_ago
    end
  end
end
