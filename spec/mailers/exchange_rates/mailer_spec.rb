require 'rails_helper'

RSpec.describe ExchangeRates::Mailer, type: :mailer do
  describe '#monthly_files' do
    let(:date) { Date.new(2023, 7, 15) }

    before do
      create(:exchange_rate_file, type: 'monthly_csv_hmrc', period_month: date.next_month.month, period_year: date.year)
      create(:exchange_rate_file, type: 'monthly_xml', period_month: date.next_month.month, period_year: date.year)
      allow_any_instance_of(described_class).to receive(:date).and_return(date)
    end

    it 'sends an email with the correct subject and attributes' do
      mail = described_class.monthly_files

      expect(mail.subject).to eq("#{date.next_month.strftime('%B %Y')} Exchange Rate Files (monthly)")
      expect(mail.from).to eq(['no-reply@example.com'])
      expect(mail.to).to eq(['user@example.com'])
    end
  end
end
