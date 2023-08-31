require 'rails_helper'

RSpec.describe ExchangeRatesMailer, type: :mailer do
  describe '#monthly_files' do
    let(:date) { Time.zone.today }

    after do
      travel_back
    end

    before do
      travel_to Time.zone.local(2023, 7, 19)
      create(:exchange_rate_file, type: 'monthly_csv_hmrc', period_month: date.next_month.month, period_year: date.year)
      create(:exchange_rate_file, type: 'monthly_xml', period_month: date.next_month.month, period_year: date.year)
    end

    context 'when email is sent it has correct attributes' do
      mail = described_class.monthly_files

      it { expect(mail.subject).to eq("#{date.next_month.strftime('%B %Y')} Exchange Rate Files (monthly)") }
      it { expect(mail.from).to eq(['no-reply@example.com']) }
      it { expect(mail.to).to eq(['user@example.com']) }
    end
  end
end
