module ScheduledJobHeartbeat
  METRIC_NAMESPACE = 'TradeTariff/ScheduledJobs'.freeze

  def record_heartbeat
    Aws::CloudWatch::Client.new.put_metric_data(
      namespace: METRIC_NAMESPACE,
      metric_data: [{
        metric_name: 'JobSuccess',
        value: 1,
        unit: 'Count',
        dimensions: [
          { name: 'Job', value: self.class.name },
          { name: 'Service', value: TradeTariffBackend.service },
          { name: 'Environment', value: Rails.env },
        ],
      }],
    )
  rescue Aws::Errors::ServiceError => e
    Rails.logger.error("scheduled_job_heartbeat_failed: job=#{self.class.name} #{e.class.name}: #{e.message}")
  end
end
