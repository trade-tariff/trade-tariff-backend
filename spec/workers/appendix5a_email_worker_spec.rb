RSpec.describe Appendix5aEmailWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:client) { instance_double(GovukNotifier) }
  let(:notify_response) { instance_double(GovukNotifierAudit, notification_uuid: SecureRandom.uuid) }
  let(:email) { 'cupid@example.com' }

  before do
    allow(GovukNotifier).to receive(:new).and_return(client)
    allow(client).to receive(:send_email).and_return(notify_response)
  end

  describe '#perform' do
    it 'sends an email via GovukNotifier with the expected personalisation' do
      worker.perform(email, 2, 3, 1)

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
  end
end
