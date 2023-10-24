RSpec.describe SpotExchangeRatesWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:body) do
    {
      to: [
        {
          quotecurrency: 'AUD',
          mid: 4.662353708,
        },
      ],
    }.to_json
  end

  describe '#perform' do
    subject(:perform) { worker.perform(today.iso8601) }

    before do
      allow(TariffSynchronizer::FileService).to receive(:write_file)
      allow(TariffSynchronizer::FileService).to receive(:file_size).and_return(1)

      create(:exchange_rate_country_currency, currency_code: 'AUD')

      stub_request(:get, 'https://example.com/v1/historic_rate.json/?amount=1&date=2023-03-31&from=GBP&to=*')
        .to_return(status: 200, body:)

      stub_request(:get, 'https://example.com/v1/historic_rate.json/?amount=1&date=2023-12-31&from=GBP&to=*')
        .to_return(status: 200, body:)

      allow(SlackNotifierService).to receive(:call).and_call_original

      perform
    end

    context 'when today is 31 march' do
      let(:today) { Date.parse('2023-03-31').beginning_of_day }

      it { expect(TariffSynchronizer::FileService).to have_received(:write_file).exactly(1).times }
      it { expect(SlackNotifierService).to have_received(:call).with(match(/Spot/)) }
      it { expect(ExchangeRateCurrencyRate.count).to eq(1) }
      it { expect(ExchangeRateFile.count).to eq(1) }
    end

    context 'when today is 31 december' do
      let(:today) { Date.parse('2023-12-31').beginning_of_day }

      it { expect(TariffSynchronizer::FileService).to have_received(:write_file).exactly(1).times }
      it { expect(SlackNotifierService).to have_received(:call).with(match(/Spot/)) }
      it { expect(ExchangeRateCurrencyRate.count).to eq(1) }
      it { expect(ExchangeRateFile.count).to eq(1) }
    end

    context 'when today is not 31 march or 31 december' do
      let(:today) { Date.parse('2023-10-19').beginning_of_day }

      it { expect(TariffSynchronizer::FileService).not_to have_received(:write_file) }
      it { expect(SlackNotifierService).not_to have_received(:call) }
      it { expect(ExchangeRateCurrencyRate.count).to eq(0) }
      it { expect(ExchangeRateFile.count).to eq(0) }
    end
  end
end
