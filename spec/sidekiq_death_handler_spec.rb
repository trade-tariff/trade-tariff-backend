RSpec.describe 'Sidekiq death handler' do
  let(:death_handler) do
    Sidekiq.default_configuration.death_handlers.last
  end

  let(:job) do
    {
      'class' => 'EnquiryForm::SendSubmissionEmailWorker',
      'jid' => '93ce163da1a9f7052e55d7c6',
      'queue' => 'default',
      'args' => ['TVUZGFEA'],
      'error_class' => 'Redis::CannotConnectError',
      'error_message' => 'user specified timeout for redis-production:6379',
      'retry_count' => 25,
    }
  end

  let(:exception) { StandardError.new('user specified timeout') }

  before do
    allow(TradeTariffBackend).to receive(:slack_failures_enabled?).and_return(true)
    allow(SlackNotifierService).to receive(:call)
  end

  it 'sends a Slack alert with structured error details' do
    death_handler.call(job, exception)

    expect(SlackNotifierService).to have_received(:call).with(
      channel: TradeTariffBackend.slack_failures_channel,
      attachments: [
        hash_including(
          color: 'danger',
          title: ':fire: Job dead: EnquiryForm::SendSubmissionEmailWorker',
          fields: include(
            hash_including(title: 'Error', value: include('Redis::CannotConnectError')),
            hash_including(title: 'JID', value: '93ce163da1a9f7052e55d7c6'),
            hash_including(title: 'Queue', value: 'default'),
            hash_including(title: 'Args', value: include('TVUZGFEA')),
            hash_including(title: 'Retries exhausted', value: '25'),
          ),
        ),
      ],
    )
  end

  context 'when slack failures are disabled' do
    before do
      allow(TradeTariffBackend).to receive(:slack_failures_enabled?).and_return(false)
    end

    it 'does not send a Slack alert' do
      death_handler.call(job, exception)

      expect(SlackNotifierService).not_to have_received(:call)
    end
  end

  context 'when the job has slack_alerts: false' do
    let(:job) { super().merge('slack_alerts' => false) }

    it 'does not send a Slack alert' do
      death_handler.call(job, exception)

      expect(SlackNotifierService).not_to have_received(:call)
    end
  end
end
