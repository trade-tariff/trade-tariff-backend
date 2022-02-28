RSpec.describe SlackNotifierService do
  before do
    allow(Rails.application.config.slack_notifier).to receive(:ping)
  end

  it 'sends a Slack message' do
    described_class.new.call('Hello Slack')

    expect(Rails.application.config.slack_notifier).to have_received(:ping).with('Hello Slack')
  end
end
