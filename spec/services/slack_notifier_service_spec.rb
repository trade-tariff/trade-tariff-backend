RSpec.describe SlackNotifierService do
  let(:slack_notifier) { instance_double('Slack::Notiifer', ping: 'pong') }

  before do
    allow(Rails.application.config).to receive(:slack_notifier).and_return(slack_notifier)
  end

  it { expect(described_class.call('Hello Slack')).to eq('pong') }
end
