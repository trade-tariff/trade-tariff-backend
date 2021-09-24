RSpec.describe TariffSynchronizer::TariffUpdatesRequester do
  describe '.perform' do
    let(:url) { 'http://example/test' }

    context 'partial content received' do
      it 'raises DownloadException' do
        stub_request(:get, url).to_raise(Curl::Err::PartialFileError)
        expect { described_class.perform('http://example/test') }.to raise_error TariffSynchronizer::TariffUpdatesRequester::DownloadException
      end
    end

    context 'unable to connect' do
      it 'raises DownloadException' do
        stub_request(:get, url).to_raise(Curl::Err::ConnectionFailedError)
        expect { described_class.perform('http://example/test') }.to raise_error TariffSynchronizer::TariffUpdatesRequester::DownloadException
      end
    end

    context 'host resolution error' do
      it 'raises DownloadException' do
        stub_request(:get, url).to_raise(Curl::Err::HostResolutionError)
        expect { described_class.perform('http://example/test') }.to raise_error TariffSynchronizer::TariffUpdatesRequester::DownloadException
      end
    end

    context 'not valid request' do
      before { stub_request(:get, url).to_return(status: 401) }

      it 'returns retry_count_exceeded? as true when not valid request' do
        response = described_class.perform('http://example/test')
        expect(response.retry_count_exceeded?).to be_truthy
      end

      it 'logs an info event' do
        tariff_synchronizer_logger_listener
        described_class.perform('http://example/test')
        expect(@logger.logged(:info).size).to be(1)
        expect(@logger.logged(:info).to_s).to match(/Delaying update fetching/)
      end
    end

    it 'returns response object if the request is successful' do
      stub_request(:get, url).to_return(status: 200, body: 'abc')

      response = described_class.perform('http://example/test')
      expect(response.content).to eq('abc')
      expect(response.response_code).to eq(200)
    end
  end
end
