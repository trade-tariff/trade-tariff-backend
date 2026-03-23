RSpec.describe ReportsMailer, type: :mailer do
  describe '#differences' do
    subject(:mail) { described_class.differences(report).tap(&:deliver_now) }

    let(:report) { Reporting::Differences.new }
    let(:attachment) { mail.attachments["differences_#{report.as_of}.xlsx"] }
    let(:xlsx_content) { "PK\x03\x04\x9D".b }

    before do
      allow(report.workbook).to receive(:read_string).and_return(xlsx_content)
    end

    it { expect(mail.subject).to eq("[HMRC Online Trade Tariff Support] UK tariff - potential issues report #{Time.zone.today.iso8601}") }
    it { expect(mail.from).to eq(['no-reply@example.com']) }
    it { expect(mail.to).to eq(['differences@example.com']) }
    it { expect(mail.bcc).to eq(['user@example.com']) }

    it 'encodes the xlsx attachment as base64' do
      expect(attachment.body.raw_source).to be_ascii_only
      expect(Base64.strict_decode64(attachment.body.raw_source)).to eq(xlsx_content)
    end
  end
end
