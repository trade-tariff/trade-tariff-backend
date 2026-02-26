RSpec.describe TariffSynchronizer::CdsUpdateDownloader do
  let(:example_date) { Date.new(2020, 10, 10) }
  let(:downloader) { described_class.new(example_date) }

  describe '#perform' do
    let(:body) do
      [{
        'filename' => 'tariff_dailyExtract_v1_20201010T235959.gzip',
        'downloadURL' => 'https://sdes.hmrc.gov.uk/api-download/156ec583-9245-484a-9f91-3919493a041a',
        'fileSize' => 12_345,
      },
       {
         'filename' => 'tariff_dailyExtract_v1_20201005T235959.gzip',
         'downloadURL' => 'https://sdes.hmrc.gov.uk/api-download/156ec583-9245-484a-9f91-3919493a042b',
         'fileSize' => 12_345,
       },
       {
         'filename' => 'tariff_dailyExtract_v1_20201004T235959.gzip',
         'downloadURL' => 'https://sdes.hmrc.gov.uk/api-download/156ec583-9245-484a-9f91-3919493a043c',
         'fileSize' => 12_345,
       }]
    end

    before do
      # rubocop:disable RSpec/VerifiedDoubleReference
      allow(downloader).to receive(:response) { instance_double('Response', body: body.to_json) }
      # rubocop:enable RSpec/VerifiedDoubleReference

      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(TariffSynchronizer::TariffDownloader).to receive(:perform)
      # rubocop:enable RSpec/AnyInstance
    end

    it 'emits a download_started instrumentation event' do
      allow(TariffSynchronizer::Instrumentation).to receive(:download_started)
      downloader.perform
      expect(TariffSynchronizer::Instrumentation).to have_received(:download_started)
    end

    context 'when response contains example_date' do
      it 'calls TariffDownloader for requested date..5 days ago', :aggregate_failures do
        allow(TariffSynchronizer::TariffDownloader).to receive(:new).with(
          body[0]['filename'], body[0]['downloadURL'], example_date, TariffSynchronizer::CdsUpdate
        ).and_call_original

        allow(TariffSynchronizer::TariffDownloader).to receive(:new).with(
          body[1]['filename'], body[1]['downloadURL'], example_date - 5.days, TariffSynchronizer::CdsUpdate
        ).and_call_original

        downloader.perform

        expect(TariffSynchronizer::TariffDownloader).to have_received(:new).with(
          body[0]['filename'], body[0]['downloadURL'], example_date, TariffSynchronizer::CdsUpdate
        )

        expect(TariffSynchronizer::TariffDownloader).to have_received(:new).with(
          body[1]['filename'], body[1]['downloadURL'], example_date - 5.days, TariffSynchronizer::CdsUpdate
        )

        expect(TariffSynchronizer::TariffDownloader).not_to have_received(:new).with(
          body[2]['filename'], body[2]['downloadURL'], example_date - 6.days, TariffSynchronizer::CdsUpdate
        )
      end

      it 'does not create missing update record' do
        expect { downloader.perform }.not_to change(TariffSynchronizer::BaseUpdate.missing, :count)
      end
    end

    context 'when response is empty' do
      let(:body) { [] }

      it 'does not call TariffDownloader' do
        allow(TariffSynchronizer::TariffDownloader).to receive(:new)
        downloader.perform
        expect(TariffSynchronizer::TariffDownloader).not_to have_received(:new)
      end

      it 'returns nil' do
        expect(downloader.perform).to be_nil
      end
    end
  end

  context 'when different http codes are returned' do
    before do
      stub_request(:post, 'https://example.com:80/oauth/token')
        .with(
          body: { 'client_id' => '123456789', 'client_secret' => '123456789', 'grant_type' => 'client_credentials' },
          headers: {
            'Accept' => '*/*',
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Content-Type' => 'application/x-www-form-urlencoded',
            'User-Agent' => 'Ruby',
          },
        )
        .to_return(status: 200, body: { 'access_token' => 'valid_token' }.to_json, headers: {})

      stub_request(:get, 'https://example.com:80/bulk-data-download/list/TARIFF-DAILY')
        .with(
          headers: {
            'Accept' => 'application/vnd.hmrc.1.0+json',
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Authorization' => 'Bearer valid_token',
            'User-Agent' => 'Trade Tariff Backend',
          },
        )
        .to_return(status: code, body: '', headers: {})
    end

    context 'when code is not 200' do
      let(:code) { 404 }

      it 'raises error' do
        expect { downloader.perform }.to raise_error TariffSynchronizer::CdsUpdateDownloader::ListDownloadFailedError, '404'
      end
    end

    context 'when code is 200 and response body is empty' do
      let(:code) { 200 }

      it 'raises error' do
        expect { downloader.perform }.to raise_error TariffSynchronizer::CdsUpdateDownloader::ListDownloadFailedError, '200'
      end
    end
  end
end
