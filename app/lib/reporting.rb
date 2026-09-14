module Reporting
  extend Reportable

  # Raised when a published report cannot be fetched from the reporting bucket,
  # so callers fail loudly instead of parsing an error body as report content.
  class FetchError < StandardError; end

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

    # Published reports live in the same reporting bucket this task already
    # reads and writes, and the reporting CDN is only CloudFront in front of
    # that bucket. Fetching a report over the public hostname left the VPC
    # through the NAT gateway, went out to a CloudFront edge and came back to
    # the very same objects, so read them from S3 instead. published_link is
    # deliberately left on the CDN host: it produces links for humans to click.
    def get_published(object_key)
      get(object_key)
    rescue Aws::Errors::ServiceError, Seahorse::Client::NetworkingError => e
      raise FetchError, "GET #{object_key} from the reporting bucket failed: #{e.message}"
    end

    def published_link(object_key)
      return get_link(object_key) unless reporting_cdn_host?

      File.join(TradeTariffBackend.reporting_cdn_host, object_key)
    end

    # Availability is a question about the object, not about the CDN, so ask S3.
    # A missing object is already a false from Aws::S3::Object#exists?; an S3
    # error is treated as "not available" to keep the previous behaviour, where
    # a failed HEAD never blew up the admin reports page.
    def published_exist?(object_key)
      exist?(object_key)
    rescue Aws::Errors::ServiceError, Seahorse::Client::NetworkingError
      false
    end

  private

    def reporting_cdn_host?
      TradeTariffBackend.reporting_cdn_host.present?
    end
  end
end
