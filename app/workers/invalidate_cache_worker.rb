class InvalidateCacheWorker
  include Sidekiq::Worker

  def perform(client = self.class.client)
    cdn = client.list_distributions.distribution_list.items.find do |d|
      d.comment == "#{ENV.fetch('ENVIRONMENT', '').capitalize} CDN"
    end

    if cdn
      client.create_invalidation({
        distribution_id: cdn.id,
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

  delegate :client, to: :class

  def self.client
    @client ||= Aws::CloudFront::Client.new
  end
end
