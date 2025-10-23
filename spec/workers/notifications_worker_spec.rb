RSpec.describe NotificationsWorker, type: :worker do
  subject(:worker) { described_class.new }

  describe '#perform' do
    let(:notification_id) { SecureRandom.uuid }

    before do
      allow(Rails.cache).to receive(:read).and_return(notification_data.to_json)
    end

    context 'when notification data is found in the cache' do
      before do
        allow(GovukNotifier).to receive(:new).and_return(notifier)
        allow(notifier).to receive(:send_email)
        allow(Rails.cache).to receive(:delete)
        worker.perform(notification_id)
      end

      let(:notifier) { instance_double(GovukNotifier) }
      let(:notification_data) do
        {
          'email' => 'foo@bar.com',
          'template_id' => 'template_123',
          'personalisation' => { 'name' => 'Foo' },
          'email_reply_to_id' => 'reply_456',
          'reference' => 'ref_789',
        }
      end

      it 'sends the email using GovukNotifier' do
        expect(notifier).to have_received(:send_email).with(
          notification_data['email'],
          notification_data['template_id'],
          notification_data['personalisation'],
          notification_data['email_reply_to_id'],
          notification_data['reference'],
        )
      end

      it 'deletes the notification data from the cache' do
        expect(Rails.cache).to have_received(:delete).with("notification_#{notification_id}")
      end
    end

    context 'when notification data is not found in the cache' do
      let(:notification_data) { nil }

      before do
        allow(Rails.logger).to receive(:error)
        worker.perform(notification_id)
      end

      it 'logs an error message' do
        expect(Rails.logger).to have_received(:error).with("Notification data not found for ID: #{notification_id}")
      end
    end
  end
end
