module Reporting
  extend Reportable

  class << self
    def get(object_key)
      return object(object_key).get.body.read if use_s3_bucket?

      return fetch_from_cdn(object_key) if use_reporting_cdn?

      File.open(File.basename(object_key))
    end

    def get_link(object_key)
      return cdn_url(object_key) if use_reporting_cdn?

      object_key
    end

    def exist?(object_key)
      return object(object_key).exists? if use_s3_bucket?

      return cdn_exists?(object_key) if use_reporting_cdn?

      File.exist?(File.basename(object_key))
    end

    private

    def fetch_from_cdn(object_key)
      Faraday.get(cdn_url(object_key)).body
    end

    def cdn_exists?(object_key)
      response = Faraday.head(cdn_url(object_key))
      response.success?
    rescue Faraday::Error
      false
    end

    def cdn_url(object_key)
      File.join(TradeTariffBackend.reporting_cdn_host, object_key)
    end

    def use_reporting_cdn?
      TradeTariffBackend.reporting_cdn_host.present?
    end

    def use_s3_bucket?
      Rails.env.production? && Rails.application.config.reporting_bucket.present? && !use_reporting_cdn?
    end
  end
end
