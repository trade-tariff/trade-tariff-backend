module Reporting
  module Reportable
    extend ActiveSupport::Concern

    def object_key
      "#{service}/reporting/#{year}/#{month}/#{day}/#{report_name}_#{service}_#{now.strftime('%Y_%m_%d')}.xlsx"
    end

    def object
      bucket.object(object_key)
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
  end
end
