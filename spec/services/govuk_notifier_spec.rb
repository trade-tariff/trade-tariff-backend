RSpec.describe GovukNotifier do
  before do
    stub_const('ENV', ENV.to_hash.merge('GOVUK_NOTIFY_API_KEY' => 'asdf'))
  end

  let(:client) { instance_spy(Notifications::Client) }
  let(:notifier) { described_class.new(client: client) }

  describe '#send_email' do
    let(:mocked_response) { build(:notifications_client_post_email_response) }

    it 'sends an email' do
      allow(notifier).to receive(:audit).and_return(nil)
      notifier.send_email('test@example.com', 'b0f0c2b2-c5f5-4f3a-8d9c-f4c8e8ea1a7c', { foo: 'bar' })
      expect(client).to have_received(:send_email).with(
        email_address: 'test@example.com',
        template_id: 'b0f0c2b2-c5f5-4f3a-8d9c-f4c8e8ea1a7c',
        personalisation: {
          foo: 'bar',
        },
      )
    end

    it 'uses the override email if set' do
      stub_const('ENV', ENV.to_hash.merge('OVERRIDE_NOTIFY_EMAIL' => 'foo@example.com'))
      allow(notifier).to receive(:audit).and_return(nil)
      notifier.send_email('test@example.com', 'b0f0c2b2-c5f5-4f3a-8d9c-f4c8e8ea1a7c', { foo: 'bar' })
      expect(client).to have_received(:send_email).with(
        email_address: 'foo@example.com',
        template_id: 'b0f0c2b2-c5f5-4f3a-8d9c-f4c8e8ea1a7c',
        personalisation: {
          foo: 'bar',
        },
      )
    end

    it 'audits the email' do
      allow(client).to receive(:send_email).and_return(mocked_response)
      notifier.send_email('test@example.com', 'b0f0c2b2-c5f5-4f3a-8d9c-f4c8e8ea1a7c', { foo: 'bar' })
      expect(GovukNotifierAudit.first).to have_attributes(
        subject: 'test',
        body: 'test',
        from_email: 'test@example.com',
        template_id: 'b0f0c2b2-c5f5-4f3a-8d9c-f4c8e8ea1a7c',
        template_version: '1',
        template_uri: '/v2/templates/b0f0c2b2-c5f5-4f3a-8d9c-f4c8e8ea1a7c',
        notification_uri: '/notifications/aceed36e-6aee-494c-a09f-88b68904bad6',
      )
    end
  end
end
