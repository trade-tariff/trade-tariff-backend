RSpec.describe ScheduledJobHeartbeat do
  let(:cloudwatch_client) { instance_double(Aws::CloudWatch::Client) }
  let(:worker_class) do
    Class.new do
      include ScheduledJobHeartbeat
      def self.name = 'TestWorker'
    end
  end
  let(:worker) { worker_class.new }

  before do
    allow(Aws::CloudWatch::Client).to receive(:new).and_return(cloudwatch_client)
    allow(cloudwatch_client).to receive(:put_metric_data)
    allow(TradeTariffBackend).to receive(:service).and_return('uk')
  end

  describe '#record_heartbeat' do
    it 'emits a JobSuccess metric to TradeTariff/ScheduledJobs' do
      worker.record_heartbeat

      expect(cloudwatch_client).to have_received(:put_metric_data).with(
        namespace: 'TradeTariff/ScheduledJobs',
        metric_data: [{
          metric_name: 'JobSuccess',
          value: 1,
          unit: 'Count',
          dimensions: [
            { name: 'Job', value: 'TestWorker' },
            { name: 'Service', value: 'uk' },
            { name: 'Environment', value: ENV.fetch('ENVIRONMENT', 'local') },
          ],
        }],
      )
    end

    it 'uses the current service in the Service dimension' do
      allow(TradeTariffBackend).to receive(:service).and_return('xi')

      worker.record_heartbeat

      expect(cloudwatch_client).to have_received(:put_metric_data).with(
        hash_including(
          metric_data: [hash_including(dimensions: include({ name: 'Service', value: 'xi' }))],
        ),
      )
    end

    it 'does not raise when CloudWatch returns a service error' do
      allow(cloudwatch_client).to receive(:put_metric_data)
        .and_raise(Aws::CloudWatch::Errors::ServiceError.new(nil, 'throttled'))
      allow(Rails.logger).to receive(:error)

      expect { worker.record_heartbeat }.not_to raise_error
    end

    it 'logs the job name and error detail when CloudWatch raises a service error' do
      allow(cloudwatch_client).to receive(:put_metric_data)
        .and_raise(Aws::CloudWatch::Errors::ServiceError.new(nil, 'throttled'))
      allow(Rails.logger).to receive(:error)

      worker.record_heartbeat

      expect(Rails.logger).to have_received(:error).with(
        a_string_including('scheduled_job_heartbeat_failed', 'TestWorker'),
      )
    end
  end
end
