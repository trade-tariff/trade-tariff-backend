RSpec.describe MonthlyExchangeRatesWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:body) do
    {
      to: [
        {
          quotecurrency: 'AED',
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

      create(:exchange_rate_country_currency, currency_code: 'AED')

      stub_request(:get, 'https://example.com/v1/historic_rate.json/?amount=1&date=2023-10-18&from=GBP&to=*')
        .to_return(status: 200, body:)

      stub_request(:get, 'https://example.com/v1/historic_rate.json/?amount=1&date=2023-10-19&from=GBP&to=*')
        .to_return(status: 200, body:)

      perform
    end

    context 'when force is true' do
      subject(:perform) { worker.perform(today.iso8601, true) }

      let(:today) { Date.parse('2023-10-19').beginning_of_day }

      it { expect(TariffSynchronizer::FileService).to have_received(:write_file).exactly(3).times }
      it { expect(ExchangeRateCurrencyRate.count).to eq(1) }
      it { expect(ActionMailer::Base.deliveries.count).to eq(1) }
    end

    context 'when tomorrow is the penultimate Thursday of the month' do
      let(:today) { Date.parse('2023-10-18').beginning_of_day }

      it { expect(TariffSynchronizer::FileService).to have_received(:write_file).exactly(3).times }
      it { expect(ExchangeRateCurrencyRate.count).to eq(1) }
      it { expect(ActionMailer::Base.deliveries.count).to eq(1) }
    end

    context 'when tomorrow is not the penultimate Thursday of the month' do
      let(:today) { Date.parse('2023-10-19').beginning_of_day }

      it { expect(TariffSynchronizer::FileService).not_to have_received(:write_file) }
      it { expect(ExchangeRateCurrencyRate.count).to eq(0) }
      it { expect(ActionMailer::Base.deliveries.count).to eq(0) }
    end
  end
end
