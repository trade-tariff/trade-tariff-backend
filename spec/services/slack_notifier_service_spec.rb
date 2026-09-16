RSpec.describe SlackNotifierService do
  let(:slack_notifier) { instance_double(Slack::Notifier, ping: 'pong') }

  before do
    allow(Rails.application.config).to receive(:slack_notifier).and_return(slack_notifier)
  end

  it { expect(described_class.call('Hello Slack')).to eq('pong') }

  it 'forwards a string message' do
    described_class.call('Hello Slack')

    expect(slack_notifier).to have_received(:ping).with('Hello Slack')
  end

  it 'forwards a positional payload hash' do
    payload = { text: 'Hello Slack', channel: '#production-alerts' }

    described_class.call(payload)

    expect(slack_notifier).to have_received(:ping).with(payload)
  end

  it 'forwards keyword options to ping' do
    described_class.call(
      text: 'Error TariffSynchronizer::FailedUpdatesError',
      channel: '#production-alerts',
    )

    expect(slack_notifier).to have_received(:ping).with(
      hash_including(
        text: 'Error TariffSynchronizer::FailedUpdatesError',
        channel: '#production-alerts',
      ),
    )
  end

  it 'forwards attachments without a text message' do
    described_class.call(
      channel: '#production-alerts',
      attachments: [{ color: 'danger' }],
    )

    expect(slack_notifier).to have_received(:ping).with(
      hash_including(
        channel: '#production-alerts',
        attachments: [{ color: 'danger' }],
      ),
    )
  end

  context 'when no notifier is configured' do
    before do
      allow(Rails.application.config).to receive(:slack_notifier).and_return(nil)
      allow(Rails.logger).to receive(:error)
    end

    it 'logs that the message was dropped instead of silently doing nothing' do
      described_class.call('Hello Slack')

      expect(Rails.logger).to have_received(:error).with(
        'slack_notifier_unconfigured: dropped a Slack message because no notifier is configured',
      )
    end

    it 'still returns nil rather than raising' do
      expect(described_class.call('Hello Slack')).to be_nil
    end
  end
end
