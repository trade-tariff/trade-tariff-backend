RSpec.describe ReportsMailer, type: :mailer do
  describe '#differences' do
    subject(:mail) { described_class.differences(report).tap(&:deliver_now) }

    let(:report) { Reporting::Differences.new }

    it { expect(mail.subject).to eq("[HMRC Online Trade Tariff Support] UK tariff - potential issues report #{Time.zone.today.iso8601}") }
    it { expect(mail.from).to eq(['no-reply@example.com']) }
    it { expect(mail.to).to eq(['differences@example.com']) }
    it { expect(mail.bcc).to eq(['user@example.com']) }
  end
end
