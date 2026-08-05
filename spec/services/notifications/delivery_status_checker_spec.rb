RSpec.describe Notifications::DeliveryStatusChecker do
  subject(:checker) { described_class.new(notification_uuid, pipeline: 'test_pipeline', identifier: '1.30') }

  let(:client) { instance_double(GovukNotifier) }
  let(:notification_uuid) { SecureRandom.uuid }

  before do
    allow(GovukNotifier).to receive(:new).and_return(client)
  end

  describe '#call' do
    it 'returns nil and does not call Notify when the notification uuid is blank' do
      blank_checker = described_class.new(nil, pipeline: 'test_pipeline', identifier: '1.30')

      expect(blank_checker.call).to be_nil
      expect(GovukNotifier).not_to have_received(:new)
    end

    it 'returns nil and does not alert when delivery succeeded' do
      allow(client).to receive(:get_email_status).and_return('delivered')

      expect(checker.call).to be_nil
    end

    %w[permanent-failure temporary-failure technical-failure].each do |status|
      it "fires delivery_failed and alerts Slack for #{status}" do
        allow(client).to receive(:get_email_status).and_return(status)
        allow(Notifications::Instrumentation).to receive(:delivery_failed)
        allow(SlackNotifierService).to receive(:call)

        result = checker.call

        expect(result).to eq(status)
        expect(Notifications::Instrumentation).to have_received(:delivery_failed).with(
          pipeline: 'test_pipeline', identifier: '1.30', notification_uuid:, status:,
        )
        expect(SlackNotifierService).to have_received(:call).with(
          "test_pipeline: notification delivery failed for 1.30 (status: #{status}) — check logs",
        )
      end
    end

    it 'rescues a Slack failure and logs it instead of raising' do
      allow(client).to receive(:get_email_status).and_return('permanent-failure')
      allow(SlackNotifierService).to receive(:call).and_raise('slack down')
      allow(Rails.logger).to receive(:error)

      expect { checker.call }.not_to raise_error

      expect(Rails.logger).to have_received(:error).with(a_string_including('test_pipeline_notification_slack_failed'))
    end
  end
end
