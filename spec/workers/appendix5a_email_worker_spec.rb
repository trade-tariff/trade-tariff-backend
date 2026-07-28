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
      worker.perform(5, 2, 3, 1)

      expect(client).not_to have_received(:send_email)
    end
  end
end
