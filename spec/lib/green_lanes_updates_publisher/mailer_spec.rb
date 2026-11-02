RSpec.describe GreenLanesUpdatesPublisher::Mailer do
  describe '#update' do
    subject(:mail) { described_class.update([], Time.zone.today).message }

    it 'reads the recipients when the email is sent, not when the class is loaded' do
      allow(TradeTariffBackend).to receive(:green_lanes_update_email).and_return(%w[a@example.com b@example.com])

      expect(mail.to).to eq(%w[a@example.com b@example.com])
    end
  end
end
