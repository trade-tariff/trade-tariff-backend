class SidekiqQueueMetricsWorker
  include Sidekiq::Worker

  # Metric-only job; reruns every 5 minutes via scheduler — do not retry-storm.
  sidekiq_options retry: false

  NAMESPACE = 'TradeTariff/Sidekiq'.freeze

  def self.client
    @client ||= Aws::CloudWatch::Client.new
  end

  def perform
    metric_data = Sidekiq::Queue.all.flat_map { |queue| metrics_for(queue) }

    self.class.client.put_metric_data(
      namespace: NAMESPACE,
      metric_data: metric_data,
    )
  end

private

  def metrics_for(queue)
    dimensions = [
      { name: 'Queue', value: queue.name },
      { name: 'Environment', value: TradeTariffBackend.environment.to_s },
    ]

    [
      { metric_name: 'QueueDepth', value: queue.size, unit: 'Count', dimensions: },
      { metric_name: 'QueueLatency', value: queue.latency, unit: 'Seconds', dimensions: },
    ]
  end
end
