RSpec.describe ExchangeRatesMailer, type: :mailer do
  describe '#monthly_files' do
    subject(:mail) { described_class.monthly_files(date).tap(&:deliver_now) }

    let(:date) { Time.zone.today }

    before do
      create(
        :exchange_rate_file,
        type: 'monthly_csv_hmrc',
        period_month: date.month,
        period_year: date.year,
      )
    end

    it { expect(mail.subject).to eq("#{date.strftime('%B %Y')} Exchange Rate Files (monthly)") }
    it { expect(mail.from).to eq(['no-reply@example.com']) }
    it { expect(mail.to).to eq(['manager@example.com']) }
    it { expect(mail.bcc).to eq(['user@example.com']) }
  end
end
