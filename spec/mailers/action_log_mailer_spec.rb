require 'rails_helper'

RSpec.describe ActionLogMailer do
  describe '#daily_report' do
    subject(:mail) { described_class.daily_report(csv_data, yesterday) }

    let(:yesterday) { Date.yesterday }
    let(:csv_data) { "ID,Action,Created At\r\n1,registered,2025-06-17" }

    before do
      allow(TradeTariffBackend).to receive(:myott_report_email).and_return('myottreport@example.com')
    end

    it 'sets the correct subject' do
      expect(mail.subject).to eq("[HMRC Online Trade Tariff] User Action Logs Report #{yesterday.strftime('%Y-%m-%d')}")
    end

    it 'sets the recipient from TradeTariffBackend.myott_report_email' do
      expect(mail.to).to eq(['myottreport@example.com'])
    end

    it 'includes one attachment' do
      expect(mail.attachments.count).to eq(1)
    end

    it 'sets the correct attachment filename' do
      attachment = mail.attachments.first
      expect(attachment.filename).to eq("action_logs_#{yesterday.strftime('%Y-%m-%d')}.csv")
    end

    it 'sets the correct attachment content type' do
      attachment = mail.attachments.first
      expect(attachment.content_type).to eq('text/csv')
    end

    it 'sets the correct attachment content' do
      attachment = mail.attachments.first
      expect(attachment.body.raw_source).to eq(csv_data)
    end

    it 'renders the email body with the correct date' do
      expect(mail.body.encoded).to include(yesterday.strftime('%Y-%m-%d'))
    end
  end
end
