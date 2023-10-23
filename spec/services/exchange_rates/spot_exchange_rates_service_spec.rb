require 'rails_helper'

RSpec.describe ExchangeRates::SpotExchangeRatesService do
  subject(:call) { described_class.new(sample_date, download:).call }

  let(:sample_date) { Time.zone.today }

  context 'when rates exist' do
    describe '.call' do
      let(:date_three_months_later) { sample_date >> 3 }

      let(:update_service) { instance_double(ExchangeRates::UpdateCurrencyRatesService, call: true) }

      let(:spot_rates) { ExchangeRateCurrencyRate.where(rate_type: 'spot', validity_start_date: sample_date).all }

      before do
        create(
          :exchange_rate_currency_rate,
          :spot_rate,
          :with_usa,
          validity_start_date: sample_date,
        )

        create(
          :exchange_rate_currency_rate,
          :spot_rate,
          :with_usa,
          validity_start_date: date_three_months_later,
          validity_end_date: date_three_months_later,
        )

        create(
          :exchange_rate_currency_rate,
          :monthly_rate,
          :with_usa,
        )

        allow(ExchangeRates::UpdateCurrencyRatesService).to receive(:new).with(sample_date, sample_date, 'spot').and_return(update_service)
        allow(ExchangeRates::UploadMonthlyFileService).to receive(:new).and_call_original

        call
      end

      context 'when download is true' do
        let(:download) { true }

        it { expect(update_service).to have_received(:call) }

        it { expect(ExchangeRates::UploadMonthlyFileService).to have_received(:new).with(spot_rates, sample_date, :spot_csv) }
      end

      context 'when download is false' do
        let(:download) { false }

        it { expect(update_service).not_to have_received(:call) }

        it { expect(ExchangeRates::UploadMonthlyFileService).to have_received(:new).with(spot_rates, sample_date, :spot_csv) }
      end
    end

    context 'when no rates exist' do
      let(:download) { false }

      it { expect { call }.to raise_error(ExchangeRates::DataNotFoundError) }
    end
  end
end
