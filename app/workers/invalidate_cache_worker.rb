class InvalidateCacheWorker
  include Sidekiq::Worker

  def perform
    client = Aws::CloudFront::Client.new

    production_cdn = client.list_distributions.distribution_list.items.select { |d| d.comment = 'Production CDN' }
    if production_cdn.count.positive?
      distribution_id = production_cdn.first.id
    end

    if distro
      client.create_invalidation({
        distribution_id: distribution_id,
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
