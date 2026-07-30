RSpec.describe Appendix5aEmailWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:client) { instance_double(GovukNotifier) }
  let(:notify_response) { instance_double(GovukNotifierAudit, notification_uuid: SecureRandom.uuid) }
  let(:email) { 'cupid@example.com' }
  let(:cupid_emails) { [email, 'backup@example.com'] }

  before do
    allow(GovukNotifier).to receive(:new).and_return(client)
    allow(client).to receive(:send_email).and_return(notify_response)
    allow(TradeTariffBackend).to receive(:cupid_team_to_emails).and_return(cupid_emails)
    allow(Appendix5aNotificationStatusCheckWorker).to receive(:perform_in)
  end

  describe 'sidekiq options' do
    it 'caps retries below Sidekiq default' do
      expect(described_class.sidekiq_options['retry']).to eq(3)
    end
  end

  describe '#perform' do
    it 'resolves the recipient email from configured index and sends via GovukNotifier' do
      worker.perform(0, 2, 3, 1)

      expect(client).to have_received(:send_email).with(
        email,
        described_class::TEMPLATE_ID,
        {
          new_count: 2,
          changed_count: 3,
          removed_count: 1,
          support_email: TradeTariffBackend.support_email,
        },
        nil,
        nil,
      )
    end

    it 'does not send an email when the index is out of range' do
      allow(Rails.logger).to receive(:error)

      worker.perform(5, 2, 3, 1)

      expect(client).not_to have_received(:send_email)
      expect(Rails.logger).to have_received(:error).with(
        a_string_including('recipient index 5 no longer resolves to a configured email'),
      )
    end

    it 'schedules a delivery status check using the resolved notification uuid' do
      worker.perform(0, 2, 3, 1)

      expect(Appendix5aNotificationStatusCheckWorker).to have_received(:perform_in).with(
        GovukNotifierStatusCheckWorker::CHECK_DELAY,
        0,
        notify_response.notification_uuid,
      )
    end

    it 'does not schedule a status check when the index is out of range' do
      worker.perform(5, 2, 3, 1)

      expect(Appendix5aNotificationStatusCheckWorker).not_to have_received(:perform_in)
    end

    it 'does not schedule a status check when the send itself fails' do
      allow(client).to receive(:send_email).and_raise(StandardError, 'notify unavailable')

      expect { worker.perform(0, 2, 3, 1) }.to raise_error(StandardError, 'notify unavailable')

      expect(Appendix5aNotificationStatusCheckWorker).not_to have_received(:perform_in)
    end

    it 'does not raise or resend the email when scheduling the status check fails' do
      allow(Appendix5aNotificationStatusCheckWorker).to receive(:perform_in).and_raise(StandardError, 'redis unavailable')
      allow(Rails.logger).to receive(:error)

      expect { worker.perform(0, 2, 3, 1) }.not_to raise_error

      expect(client).to have_received(:send_email).once
      expect(Rails.logger).to have_received(:error).with(
        a_string_including('appendix5a_notification_status_check_schedule_failed', 'recipient_index=0', 'redis unavailable'),
      )
    end
  end
end
