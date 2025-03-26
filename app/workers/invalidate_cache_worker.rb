class InvalidateCacheWorker
  include Sidekiq::Worker

  def perform
    creds = Aws::ECSCredentials.new(retries: 3)
    client = Aws::CloudFront::Client.new(credentials: creds)

    production_cdn = client.list_distributions.distribution_list.items.find { |d| d.comment = ENV.fetch('CDN_DISTRIBUTION_NAME', 'Production CDN') }

    if production_cdn
      client.create_invalidation({
        distribution_id: production_cdn.id,
        invalidation_batch: {
          paths: {
            quantity: 1,
            items: ['*'],
          },
          caller_reference: 'InvalidateCacheWorker',
        },
      })
    end
  end
end
