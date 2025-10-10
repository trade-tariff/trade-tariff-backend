RSpec.describe ReportsMailer, type: :mailer do
  describe '#differences' do
    subject(:mail) { described_class.differences(report).tap(&:deliver_now) }

    let(:report) { Reporting::Differences.new }

    it { expect(mail.subject).to eq("[HMRC Online Trade Tariff Support] UK tariff - potential issues report #{Time.zone.today.iso8601}") }
    it { expect(mail.from).to eq(['no-reply@example.com']) }
    it { expect(mail.to).to eq(['differences@example.com']) }
    it { expect(mail.bcc).to eq(['user@example.com']) }
  end

  describe '#delta' do
    subject(:mail) { described_class.delta(report).tap(&:deliver_now) }

    let(:start_date) { Time.zone.today.strftime('%Y_%m_%d') }
    let(:report) do
      {
        dates: start_date,
        total_records: 2,
        commodity_changes: [
          { commodity_code: '0101000000', type: 'Measure' },
          { commodity_code: '0102000000', type: 'GoodsNomenclature' },
        ],
        package: Axlsx::Package.new,
      }
    end

    before do
      allow(TradeTariffBackend).to receive(:delta_report_to_emails).and_return('delta@example.com')
      allow(DeltaReportService).to receive(:generate).and_return(report)
    end

    it { expect(mail.subject).to eq("[HMRC Online Trade Tariff] - UK tariff changes report #{start_date}") }
    it { expect(mail.from).to eq(['no-reply@example.com']) }
    it { expect(mail.to).to eq(['delta@example.com']) }
    it { expect(mail.bcc).to be_nil }
  end
end
