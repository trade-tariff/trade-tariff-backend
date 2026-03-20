module Reporting
  extend Reportable

  class << self
    def get(object_key)
      if Rails.env.production?
        object(object_key).get.body.read
      else
        File.open(File.basename(object_key))
      end
    end

    def get_link(object_key)
      if Rails.env.production?
        File.join(TradeTariffBackend.reporting_cdn_host, object_key)
      else
        object_key
      end
    end

    def exist?(object_key)
      if Rails.env.production?
        object(object_key).exists?
      else
        File.exist?(File.basename(object_key))
      end
    end

    def get_published(object_key)
      return get(object_key) unless reporting_cdn_host?

      Faraday.get(published_link(object_key)).body
    end

    def published_link(object_key)
      return get_link(object_key) unless reporting_cdn_host?

      File.join(TradeTariffBackend.reporting_cdn_host, object_key)
    end

    def published_exist?(object_key)
      return exist?(object_key) unless reporting_cdn_host?

      response = Faraday.head(published_link(object_key))
      response.success?
    rescue Faraday::Error
      false
    end

    private

    def reporting_cdn_host?
      TradeTariffBackend.reporting_cdn_host.present?
    end
  end
end
