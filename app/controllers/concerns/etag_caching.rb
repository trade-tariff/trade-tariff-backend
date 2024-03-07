module EtagCaching
  extend ActiveSupport::Concern

  # We use ETags so this can be low, if the data hasn't changed and we've not
  # deployed then CloudFront will just receive a empty 304 response and there
  # will only be a single fast db query to check tariff_updates table
  CDN_CACHE_LIFETIME = 2.minutes

  included do
    etag { TradeTariffBackend.revision || Rails.env }
    etag { actual_date }
    before_action :set_cache_headers, if: :http_caching_enabled?
  end

  protected

  def set_cache_headers
    if request.get? || request.head?
      set_cache_lifetime
      set_cache_etag
    else
      no_store
    end
  end

  def set_cache_lifetime
    expires_in CDN_CACHE_LIFETIME, public: true
  end

  def set_cache_etag
    update = TariffSynchronizer::BaseUpdate.most_recent_applied

    if update
      fresh_when last_modified: update.applied_at, etag: update
    end
  end

  def http_caching_enabled?
    Rails.configuration.action_controller.perform_caching
  end

  module ClassMethods
    def no_caching
      define_method :set_cache_headers do
        no_store
      end
    end

    def time_based_caching
      define_method :set_cache_etag do
        # don't set etag
      end
    end
  end
end
