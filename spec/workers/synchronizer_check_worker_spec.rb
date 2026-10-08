RSpec.describe SynchronizerCheckWorker, type: :worker do
  let(:cloudwatch_client) { instance_double(Aws::CloudWatch::Client) }
  let(:environment) { ENV.fetch('ENVIRONMENT', 'local') }

  def age_metric(service:, value:)
    {
      namespace: 'TradeTariff/TariffSync',
      metric_data: [{
        metric_name: 'AgeMinutes',
        value: value,
        unit: 'None',
        dimensions: [
          { name: 'Service', value: service },
          { name: 'Environment', value: environment },
        ],
      }],
    }
  end

  def heartbeat(service:)
    {
      namespace: 'TradeTariff/ScheduledJobs',
      metric_data: [{
        metric_name: 'JobSuccess',
        value: 1,
        unit: 'Count',
        dimensions: [
          { name: 'Job', value: 'SynchronizerCheckWorker' },
          { name: 'Service', value: service },
          { name: 'Environment', value: environment },
        ],
      }],
    }
  end

  describe 'sidekiq options' do
    it 'does not retry metric-only jobs' do
      expect(described_class.sidekiq_options['retry']).to be(false)
    end
  end

  describe '#perform' do
    subject(:perform) { described_class.new.perform }

    before do
      allow(Aws::CloudWatch::Client).to receive(:new).and_return(cloudwatch_client)
      allow(cloudwatch_client).to receive(:put_metric_data)
      allow(NewRelic::Agent).to receive(:record_custom_event)
      allow(TradeTariffBackend).to receive(:service).and_return(service)
    end

    context 'when the UK service is running' do
      let(:service) { 'uk' }

      context 'when there are no applied updates' do
        before { perform }

        it 'sends the sentinel age' do
          expect(cloudwatch_client).to have_received(:put_metric_data)
            .with(age_metric(service: 'uk', value: SynchronizerCheckWorker::NO_SYNC_SENTINEL_MINUTES))
        end

        it 'sends the heartbeat' do
          expect(cloudwatch_client).to have_received(:put_metric_data).with(heartbeat(service: 'uk'))
        end

        it 'does not send a New Relic event' do
          expect(NewRelic::Agent).not_to have_received(:record_custom_event)
        end
      end

      context 'when the most recent applied update is recent' do
        before do
          create :base_update, :applied, applied_at: 2.hours.ago
          perform
        end

        it 'sends an age close to 120 minutes' do
          expect(cloudwatch_client).to have_received(:put_metric_data)
            .with(age_metric(service: 'uk', value: be_within(2).of(120)))
        end
      end

      context 'when the most recent applied update is stale' do
        before do
          create :base_update, :applied, applied_at: 25.hours.ago
          perform
        end

        it 'sends an age over 24 hours' do
          expect(cloudwatch_client).to have_received(:put_metric_data)
            .with(age_metric(service: 'uk', value: be > 1440))
        end
      end

      context 'when it is a Monday' do
        before do
          travel_to Time.zone.now.next_occurring(:monday)
          create :base_update, :applied, applied_at: 2.days.ago
          perform
        end

        it 'still sends the age, because only XI is quiet on Sunday to Tuesday' do
          expect(cloudwatch_client).to have_received(:put_metric_data)
            .with(age_metric(service: 'uk', value: be > 1440))
        end
      end

      context 'when CloudWatch rejects the age metric' do
        before do
          allow(cloudwatch_client).to receive(:put_metric_data)
            .with(hash_including(namespace: 'TradeTariff/TariffSync'))
            .and_raise(Aws::CloudWatch::Errors::ServiceError.new(nil, 'throttled'))
          allow(Rails.logger).to receive(:error)
        end

        it 'does not raise' do
          expect { perform }.not_to raise_error
        end

        it 'logs the failure' do
          perform

          expect(Rails.logger).to have_received(:error)
            .with('tariff_sync_age_metric_failed: Aws::CloudWatch::Errors::ServiceError: throttled')
        end

        it 'still sends the heartbeat' do
          perform

          expect(cloudwatch_client).to have_received(:put_metric_data).with(heartbeat(service: 'uk'))
        end
      end
    end

    context 'when the XI service is running' do
      let(:service) { 'xi' }

      context 'when on a day with no TARIC updates (Sunday, Monday, Tuesday)' do
        before do
          travel_to Time.zone.now.next_occurring(:monday)
          create :base_update, :applied, applied_at: 2.days.ago
          perform
        end

        it 'does not send the age' do
          expect(cloudwatch_client).not_to have_received(:put_metric_data)
            .with(hash_including(namespace: 'TradeTariff/TariffSync'))
        end

        it 'sends the heartbeat' do
          expect(cloudwatch_client).to have_received(:put_metric_data).with(heartbeat(service: 'xi'))
        end
      end

      context 'when on a day with no TARIC updates and there are no applied updates' do
        before do
          travel_to Time.zone.now.next_occurring(:monday)
          perform
        end

        it 'does not send the sentinel age' do
          expect(cloudwatch_client).not_to have_received(:put_metric_data)
            .with(hash_including(namespace: 'TradeTariff/TariffSync'))
        end

        it 'sends the heartbeat' do
          expect(cloudwatch_client).to have_received(:put_metric_data).with(heartbeat(service: 'xi'))
        end
      end

      context 'when on a day with TARIC updates (Wednesday to Saturday)' do
        before do
          travel_to Time.zone.now.next_occurring(:wednesday)
          create :base_update, :applied, applied_at: 2.hours.ago
          perform
        end

        it 'sends an age close to 120 minutes' do
          expect(cloudwatch_client).to have_received(:put_metric_data)
            .with(age_metric(service: 'xi', value: be_within(2).of(120)))
        end

        it 'sends the heartbeat' do
          expect(cloudwatch_client).to have_received(:put_metric_data).with(heartbeat(service: 'xi'))
        end
      end

      context 'when on a day with TARIC updates and there are no applied updates' do
        before do
          travel_to Time.zone.now.next_occurring(:wednesday)
          perform
        end

        it 'sends the sentinel age' do
          expect(cloudwatch_client).to have_received(:put_metric_data)
            .with(age_metric(service: 'xi', value: SynchronizerCheckWorker::NO_SYNC_SENTINEL_MINUTES))
        end
      end
    end
  end
end
