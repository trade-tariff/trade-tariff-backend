RSpec.describe TariffSynchronizer::CdsUpdateDownloader do
  let(:example_date) { Date.new(2020, 10, 10) }
  let(:downloader) { described_class.new(example_date) }

  describe '.download' do
    context 'when sync variables are set' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('HMRC_API_HOST').and_return('https://example.com')
        allow(ENV).to receive(:[]).with('HMRC_CLIENT_ID').and_return('client')
        allow(ENV).to receive(:[]).with('HMRC_CLIENT_SECRET').and_return('secret')
        allow(TradeTariffBackend).to receive(:with_redis_lock).and_yield
      end

      it 'invokes sync within a redis lock' do
        allow(described_class).to receive(:sync)

        described_class.download(initial_date: Date.new(2020, 9, 1))

        expect(described_class).to have_received(:sync).with(initial_date: Date.new(2020, 9, 1))
        expect(TradeTariffBackend).to have_received(:with_redis_lock)
      end

      it 'emits a download_completed instrumentation event' do
        allow(described_class).to receive(:sync)
        allow(TariffSynchronizer::Instrumentation).to receive(:download_completed)

        described_class.download(initial_date: Date.new(2020, 9, 1))

        expect(TariffSynchronizer::Instrumentation).to have_received(:download_completed)
      end
    end

    context 'when sync variables are not set' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('HMRC_API_HOST').and_return(nil)
      end

      it 'does not start sync process' do
        allow(described_class).to receive(:sync)

        described_class.download

        expect(described_class).not_to have_received(:sync)
      end

      it 'emits a sync_run_failed instrumentation event' do
        allow(TariffSynchronizer::Instrumentation).to receive(:sync_run_failed)

        described_class.download

        expect(TariffSynchronizer::Instrumentation).to have_received(:sync_run_failed)
      end
    end

    context 'when a download exception' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('HMRC_API_HOST').and_return('https://example.com')
        allow(ENV).to receive(:[]).with('HMRC_CLIENT_ID').and_return('client')
        allow(ENV).to receive(:[]).with('HMRC_CLIENT_SECRET').and_return('secret')
        allow(TradeTariffBackend).to receive(:with_redis_lock).and_yield
        allow(described_class).to receive(:sync)
          .and_raise(TariffSynchronizer::TariffUpdatesRequester::RetriableDownloadError.new('url'))
      end

      it 'raises a retriable download error ending the process' do
        expect { described_class.download }.to raise_error TariffSynchronizer::TariffUpdatesRequester::RetriableDownloadError
      end
    end
  end

  describe '.sync' do
    it 'calls perform for each date in the applicable download range' do
      create :cds_update, :applied, issue_date: 1.day.ago.to_date

      (20.days.ago.to_date..Time.zone.today).each do |download_date|
        allow(described_class).to receive(:new).with(download_date).and_return(instance_double(described_class, perform: nil))
      end

      described_class.sync(initial_date: 20.days.ago.to_date)

      (20.days.ago.to_date..Time.zone.today).each do |download_date|
        expect(described_class).to have_received(:new).with(download_date)
      end
    end
  end

  describe '.downloaded_todays_file?' do
    subject { described_class.downloaded_todays_file? }

    context 'when todays file is present in table' do
      before { create :cds_update, example_date: Time.zone.yesterday }

      it { is_expected.to be true }
    end

    context 'when todays file is not present in table' do
      it { is_expected.to be false }
    end

    context 'when yesterdays file queued in table' do
      before { create :cds_update, example_date: 2.days.ago.to_date }

      it { is_expected.to be false }
    end
  end

  describe '.applicable_download_date_range' do
    it_behaves_like 'an applicable download date range', :cds_update do
      subject(:applicable_download_date_range) { described_class.applicable_download_date_range(initial_date: Date.new(2020, 9, 1)) }

      let(:initial_date) { Date.new(2020, 9, 1) }
    end
  end

  describe '#perform' do
    let(:response) { instance_double(Net::HTTPResponse, body: body.to_json) }
    let(:tariff_downloader) { instance_double(TariffSynchronizer::TariffDownloader, perform: nil) }

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
      allow(downloader).to receive(:response).and_return(response)
      allow(TariffSynchronizer::TariffDownloader).to receive(:new).and_return(tariff_downloader)
    end

    it 'emits a download_started instrumentation event' do
      allow(TariffSynchronizer::Instrumentation).to receive(:download_started)
      downloader.perform
      expect(TariffSynchronizer::Instrumentation).to have_received(:download_started)
    end

    context 'when response contains example_date' do
      it 'calls TariffDownloader for requested date..5 days ago', :aggregate_failures do
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
