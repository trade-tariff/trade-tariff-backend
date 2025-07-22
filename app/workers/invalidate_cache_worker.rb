class InvalidateCacheWorker
  include Sidekiq::Worker

  SERVICES = ['/uk', '/xi', ''].freeze
  PATHS = %w[/api/*].freeze

  def perform(client = self.class.client)
    cdn = client.list_distributions.distribution_list.items.find do |d|
      d.comment == "#{ENV.fetch('ENVIRONMENT', '').capitalize} CDN"
    end

    if cdn
      client.create_invalidation({
        distribution_id: cdn.id,
        invalidation_batch: {
          paths: { quantity: paths.size, items: paths },
          caller_reference:,
        },
      })
    end
  end

  delegate :client, to: :class

  def self.client
    @client ||= Aws::CloudFront::Client.new
  end

  def paths
    SERVICES.product(PATHS).map do |service, path|
      "#{service}#{path}"
    end
  end

  def caller_reference
    @caller_reference ||= "#{ENV.fetch('ENVIRONMENT', '').capitalize} CDN Invalidation #{Time.zone.now.to_i}"
  end
end
