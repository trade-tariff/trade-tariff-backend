RSpec.describe ExchangeRates::XeApi do
  let(:mock_response_body) do
    {
      "terms": 'http://www.xe.com/legal/dfs.php',
      "privacy": 'http://www.xe.com/privacy.php',
      "from": 'GBP',
      "amount": 1.0,
      "timestamp": '2023-08-14T12:00:00Z',
      "to": [
        {
          "quotecurrency": 'AED',
          "mid": 4.662353708,
        },
        {
          "quotecurrency": 'AFN',
          "mid": 107.3434031351,
        },
      ],
    }.to_json
  end

  let(:faraday_mock) { instance_double(Faraday::Connection) }

  before do
    allow(described_class).to receive(:client).and_return(faraday_mock)
  end

  describe '#get_all_historic_rates' do
    subject(:get_historic_rates) { described_class.new.get_all_historic_rates }

    context 'when the request is successful' do
      before do
        response_double = instance_double(Faraday::Response, success?: true, body: mock_response_body)
        allow(faraday_mock).to receive(:get).and_return(response_double)
      end

      it 'returns parsed JSON response' do
        expect(get_historic_rates).to be_a(Hash)
      end
    end

    context 'when the request is unsuccessful' do
      before do
        response_double = instance_double(Faraday::Response, success?: false, status: 500)
        allow(faraday_mock).to receive(:get).and_return(response_double)
      end

      it 'raises XeApiError' do
        expect { get_historic_rates }.to raise_error(ExchangeRates::XeApi::XeApiError, 'Server error: Unsuccessful response code 500')
      end
    end

    context 'when Faraday encounters an error' do
      before do
        allow(faraday_mock).to receive(:get).and_raise(Faraday::Error.new('Connection error'))
      end

      it 'raises XeApiError' do
        expect { get_historic_rates }.to raise_error(ExchangeRates::XeApi::XeApiError, 'Server error: Connection error')
      end
    end
  end
end
