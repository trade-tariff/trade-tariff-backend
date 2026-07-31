RSpec.describe Notifications::EmailWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:client) { instance_double(GovukNotifier) }
  let(:notify_response) { instance_double(GovukNotifierAudit, notification_uuid: SecureRandom.uuid) }
  let(:email) { 'recipient@example.com' }
  let(:template_id) { SecureRandom.uuid }
  let(:personalisation) { { version: '1.30' } }

  before do
    allow(GovukNotifier).to receive(:new).and_return(client)
    allow(client).to receive(:send_email).and_return(notify_response)
    stub_const('TestNotificationStatusCheckWorker', Class.new { include Sidekiq::Worker })
    allow(TestNotificationStatusCheckWorker).to receive(:perform_in)
  end

  describe '#perform' do
    it 'sends the email with the given template id and personalisation' do
      worker.perform(email, template_id, personalisation, 'TestNotificationStatusCheckWorker', ['1.30'])

      expect(client).to have_received(:send_email).with(email, template_id, personalisation, nil, nil)
    end

    it 'schedules the given status-check worker class with the given args and the resolved notification uuid' do
      worker.perform(email, template_id, personalisation, 'TestNotificationStatusCheckWorker', ['1.30'])

      expect(TestNotificationStatusCheckWorker).to have_received(:perform_in).with(
        GovukNotifierStatusCheckWorker::CHECK_DELAY,
        '1.30',
        notify_response.notification_uuid,
      )
    end

    it 'lets a send_email failure propagate without scheduling a status check' do
      allow(client).to receive(:send_email).and_raise(StandardError, 'notify unavailable')

      expect { worker.perform(email, template_id, personalisation, 'TestNotificationStatusCheckWorker', ['1.30']) }
        .to raise_error(StandardError, 'notify unavailable')

      expect(TestNotificationStatusCheckWorker).not_to have_received(:perform_in)
    end

    it 'does not raise or resend the email when scheduling the status check fails' do
      allow(TestNotificationStatusCheckWorker).to receive(:perform_in).and_raise(StandardError, 'redis unavailable')
      allow(Rails.logger).to receive(:error)

      expect { worker.perform(email, template_id, personalisation, 'TestNotificationStatusCheckWorker', ['1.30']) }.not_to raise_error

      expect(client).to have_received(:send_email).once
      expect(Rails.logger).to have_received(:error).with(
        a_string_including(
          'notifications_email_worker_status_check_schedule_failed',
          'redis unavailable',
          'TestNotificationStatusCheckWorker',
          '1.30',
          notify_response.notification_uuid,
        ),
      )
    end
  end
end
