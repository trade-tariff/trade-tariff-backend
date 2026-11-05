RSpec.describe GreenLanesUpdatesPublisher::Mailer do
  describe '#update' do
    subject(:mail) { described_class.update([], Time.zone.today, %w[a@example.com b@example.com]).message }

    before { allow(TradeTariffBackend).to receive(:green_lanes_update_email) }

    it 'sends to the recipients it is given' do
      expect(mail.to).to eq(%w[a@example.com b@example.com])
    end

    it 'does not look up the recipients again' do
      mail
      expect(TradeTariffBackend).not_to have_received(:green_lanes_update_email)
    end
  end
end
