RSpec.describe Appendix5aNotificationStatusCheckWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:recipient_index) { 0 }
  let(:notification_uuid) { SecureRandom.uuid }
  let(:notifier) { instance_double(GovukNotifier) }
  let(:status) { 'delivered' }

  before do
    allow(GovukNotifier).to receive(:new).and_return(notifier)
    allow(notifier).to receive(:get_email_status).and_return(status)
    allow(SlackNotifierService).to receive(:call)
    allow(Rails.logger).to receive(:error)
  end

  context 'when notification_uuid is blank' do
    it 'does nothing' do
      worker.perform(recipient_index, nil)

      expect(notifier).not_to have_received(:get_email_status)
      expect(SlackNotifierService).not_to have_received(:call)
    end
  end

  context 'when status is delivered' do
    it 'does not alert' do
      worker.perform(recipient_index, notification_uuid)

      expect(SlackNotifierService).not_to have_received(:call)
      expect(Rails.logger).not_to have_received(:error)
    end
  end

  context 'when status is permanent failure' do
    let(:status) { GovukNotifier::PERMANENT_FAILURE }

    it 'logs an error and alerts slack' do
      worker.perform(recipient_index, notification_uuid)

      expect(Rails.logger).to have_received(:error).with(a_string_including('appendix5a_notification_delivery failed'))
      expect(SlackNotifierService).to have_received(:call).with(a_string_including("recipient index #{recipient_index}"))
    end
  end

  context 'when status is temporary failure' do
    let(:status) { GovukNotifier::TEMPORARY_FAILURE }

    it 'logs an error and alerts slack' do
      worker.perform(recipient_index, notification_uuid)

      expect(SlackNotifierService).to have_received(:call)
    end
  end

  context 'when status is technical failure' do
    let(:status) { GovukNotifier::TECHNICAL_FAILURE }

    it 'logs an error and alerts slack' do
      worker.perform(recipient_index, notification_uuid)

      expect(SlackNotifierService).to have_received(:call)
    end
  end
end
