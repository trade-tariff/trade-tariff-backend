RSpec.describe TariffSynchronizer::TariffUpdatesRequester do
  describe '.perform' do
    shared_examples_for 'a request to download an update' do
      subject(:response) { described_class.perform('http://example/test') }

      let(:url) { 'http://example/test' }

      context 'when a 200 success response is returned' do
        before do
          stub_request(:get, url).to_return(status: 200, body: 'abc')
        end

        it { expect(response.content).to eq('abc') }
        it { expect(response.response_code).to eq(200) }
      end

      context 'when a Faraday:Error is propagated' do
        before do
          stub_request(:get, url).to_raise(Faraday::Error)
        end

        it { expect { described_class.perform('http://example/test') }.to raise_error TariffSynchronizer::TariffUpdatesRequester::DownloadException }
      end

      context 'when a 401 response is returned' do
        before do
          stub_request(:get, url).to_return(status: 401)
        end

        it { expect(response).to be_retry_count_exceeded }

        it 'emits a download_retried instrumentation event' do
          allow(TariffSynchronizer::Instrumentation).to receive(:download_retried)

          response

          expect(TariffSynchronizer::Instrumentation).to have_received(:download_retried)
        end
      end
    end

    it_behaves_like 'a request to download an update' do
      before { allow(TradeTariffBackend).to receive(:xi?).and_return(true) }
    end

    it_behaves_like 'a request to download an update' do
      before { allow(TradeTariffBackend).to receive(:xi?).and_return(false) }
    end
  end
end
