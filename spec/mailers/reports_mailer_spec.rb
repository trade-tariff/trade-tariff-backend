RSpec.describe ReportsMailer, type: :mailer do
  describe '#differences' do
    subject(:mail) { described_class.differences(report).tap(&:deliver_now) }

    let(:report) { Reporting::Differences.new }

    it { expect(mail.subject).to eq("[HMRC Online Trade Tariff Support] UK tariff - potential issues report #{Time.zone.today.iso8601}") }
    it { expect(mail.from).to eq(['no-reply@example.com']) }
    it { expect(mail.to).to eq(['differences@example.com']) }
    it { expect(mail.bcc).to eq(['user@example.com']) }
  end

  describe '#commodity_watchlist' do
    subject(:mail) { described_class.commodity_watchlist(date, package).tap(&:deliver_now) }

    let(:date) { '2024_08_11' }
    let(:package) { Axlsx::Package.new }

    before do
      allow(TradeTariffBackend).to receive(:delta_report_to_emails).and_return('watchlist@example.com')
    end

    it { expect(mail.subject).to eq("[HMRC Online Trade Tariff] - UK tariff changes report #{date}") }
    it { expect(mail.from).to eq(['no-reply@example.com']) }
    it { expect(mail.to).to eq(['watchlist@example.com']) }
    it { expect(mail.bcc).to be_nil }

    it 'attaches the Excel file with correct filename' do
      expect(mail.attachments.size).to eq(1)
      expect(mail.attachments.first.filename).to eq("commodity_watchlist_#{date}.xlsx")
    end
  end
end
