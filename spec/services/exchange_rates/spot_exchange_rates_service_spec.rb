RSpec.describe ExchangeRates::SpotExchangeRatesService do
  subject(:call) { described_class.new(sample_date, download:).call }

  let(:sample_date) { Time.zone.today }

  context 'when rates exist' do
    describe '.call' do
      let(:update_service) { instance_double(ExchangeRates::UpdateCurrencyRatesService, call: true) }

      let(:spot_rates) { ExchangeRateCurrencyRate.by_type('spot').all }

      before do
        create(
          :exchange_rate_currency_rate,
          :spot_rate,
          :with_usa,
          validity_start_date: sample_date,
        )

        allow(ExchangeRates::UpdateCurrencyRatesService).to receive(:new).with(sample_date, sample_date, 'spot').and_return(update_service)

        allow(ExchangeRateCurrencyRate).to receive(:for_month).and_return(spot_rates)

        allow(ExchangeRates::UploadFileService).to receive(:new).and_call_original

        call
      end

      context 'when download is true' do
        let(:download) { true }

        it { expect(update_service).to have_received(:call) }

        it { expect(ExchangeRates::UploadFileService).to have_received(:new).with(spot_rates, sample_date, :spot_csv, sample_date) }

        it { expect(ExchangeRateCurrencyRate).to have_received(:for_month).with(sample_date.month, sample_date.year, 'spot') }
      end

      context 'when download is false' do
        let(:download) { false }

        it { expect(update_service).not_to have_received(:call) }

        it { expect(ExchangeRates::UploadFileService).to have_received(:new).with(spot_rates, sample_date, :spot_csv, sample_date) }

        it { expect(ExchangeRateCurrencyRate).to have_received(:for_month).with(sample_date.month, sample_date.year, 'spot') }
      end
    end

    context 'when no rates exist' do
      let(:download) { false }

      it { expect { call }.to raise_error(ExchangeRates::DataNotFoundError) }
    end
  end
end
