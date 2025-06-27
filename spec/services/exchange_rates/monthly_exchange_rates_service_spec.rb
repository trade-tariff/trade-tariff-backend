RSpec.describe ExchangeRates::MonthlyExchangeRatesService do
  describe '.call' do
    subject(:call) { described_class.new(date, sample_date, download:).call }

    let(:date) { sample_date.next_month }
    let(:sample_date) { Time.zone.today }

    let(:update_service) { instance_double(ExchangeRates::UpdateCurrencyRatesService, call: true) }

    before do
      create(
        :exchange_rate_currency_rate,
        :monthly_rate,
        :with_usa,
        validity_start_date: date,
      )
      allow(ExchangeRates::UpdateCurrencyRatesService).to receive(:new).with(date, sample_date, 'monthly').and_return(update_service)
      allow(ExchangeRates::UploadFileService).to receive(:new).and_call_original

      call
    end

    context 'when download is true' do
      let(:download) { true }

      it { expect(update_service).to have_received(:call) }

      it { expect(ExchangeRates::UploadFileService).to have_received(:new).with(anything, date, :monthly_csv, sample_date) }
      it { expect(ExchangeRates::UploadFileService).to have_received(:new).with(anything, date, :monthly_xml, sample_date) }
      it { expect(ExchangeRates::UploadFileService).to have_received(:new).with(anything, date, :monthly_csv_hmrc, sample_date) }
    end

    context 'when download is false' do
      let(:download) { false }

      it { expect(update_service).not_to have_received(:call) }

      it { expect(ExchangeRates::UploadFileService).to have_received(:new).with(anything, date, :monthly_csv, sample_date) }
      it { expect(ExchangeRates::UploadFileService).to have_received(:new).with(anything, date, :monthly_xml, sample_date) }
      it { expect(ExchangeRates::UploadFileService).to have_received(:new).with(anything, date, :monthly_csv_hmrc, sample_date) }
    end
  end
end
