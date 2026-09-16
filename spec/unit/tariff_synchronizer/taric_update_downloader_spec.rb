RSpec.describe TariffSynchronizer::TaricUpdateDownloader do
  let(:example_date) { Date.new(2010, 1, 1) }

  describe '.download' do
    context 'when sync variables are set' do
      before do
        allow(TaricSynchronizer).to receive_messages(username: 'user', password: 'pass', host: 'http://example.com')
        allow(TradeTariffBackend).to receive(:with_redis_lock).and_yield
        allow(TradeTariffBackend).to receive(:patch_broken_taric_downloads?).and_return(false)
      end

      it 'invokes sync within a redis lock' do
        allow(described_class).to receive(:sync)

        described_class.download(initial_date: Date.new(2012, 6, 6))

        expect(described_class).to have_received(:sync).with(initial_date: Date.new(2012, 6, 6))
        expect(TradeTariffBackend).to have_received(:with_redis_lock)
      end

      it 'emits a download_completed instrumentation event' do
        allow(described_class).to receive(:sync)
        allow(TariffSynchronizer::Instrumentation).to receive(:download_completed)

        described_class.download(initial_date: Date.new(2012, 6, 6))

        expect(TariffSynchronizer::Instrumentation).to have_received(:download_completed)
      end

      context 'when patch_broken_taric_downloads is set to true' do
        before do
          allow(TradeTariffBackend).to receive(:patch_broken_taric_downloads?).and_return(true)
        end

        it 'invokes sync_patched' do
          allow(described_class).to receive(:sync_patched)

          described_class.download

          expect(described_class).to have_received(:sync_patched)
        end
      end
    end

    context 'when sync variables are not set' do
      before do
        allow(TaricSynchronizer).to receive_messages(username: nil, password: 'pass', host: 'http://example.com')
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
  end

  describe '.sync' do
    it 'calls perform for each date in the applicable download range' do
      create :taric_update, :applied, issue_date: 1.day.ago.to_date

      (20.days.ago.to_date..Time.zone.today).each do |download_date|
        allow(described_class).to receive(:new).with(download_date).and_return(instance_double(described_class, perform: nil))
      end

      described_class.sync(initial_date: 20.days.ago.to_date)

      (20.days.ago.to_date..Time.zone.today).each do |download_date|
        expect(described_class).to have_received(:new).with(download_date)
      end
    end
  end

  describe '.sync_patched' do
    before do
      allow(TariffSynchronizer::TaricUpdateDownloaderPatched).to receive(:new).and_return(instance_double(TariffSynchronizer::TaricUpdateDownloaderPatched, perform: nil))
    end

    it 'calls the patched downloader with the next applicable update' do
      create :taric_update, :applied, issue_date: 1.day.ago

      described_class.sync_patched

      expect(TariffSynchronizer::TaricUpdateDownloaderPatched).to have_received(:new).with(an_instance_of(TariffSynchronizer::TaricUpdate)).once
    end
  end

  describe '.applicable_update' do
    subject(:applicable_update) { described_class.applicable_update.as_json }

    context 'when there is an unbroken sequence of applied and pending updates' do
      before do
        create(:taric_update, :pending, example_date: Date.parse('2021-12-03'), sequence_number: '203')
        create(:taric_update, :applied, example_date: Date.parse('2021-12-02'), sequence_number: '202')
      end

      let(:expected_update) do
        { 'filename' => '2021-12-04_TGB21204.xml', 'issue_date' => '2021-12-04' }
      end

      it { is_expected.to eq(expected_update) }
    end

    context 'when there is an unbroken sequence of applied updates' do
      before do
        create(:taric_update, :applied, example_date: Date.parse('2021-12-03'), sequence_number: '203')
        create(:taric_update, :applied, example_date: Date.parse('2021-12-02'), sequence_number: '202')
      end

      let(:expected_update) do
        { 'filename' => '2021-12-04_TGB21204.xml', 'issue_date' => '2021-12-04' }
      end

      it { is_expected.to eq(expected_update) }
    end

    context 'when there are broken sequence updates' do
      before do
        create(:taric_update, :pending, example_date: Date.parse('2021-12-03'), sequence_number: '203')
        create(:taric_update, :applied, example_date: Date.parse('2021-12-02'), sequence_number: '201')
      end

      it { is_expected.to be_nil }
    end

    context 'when there are no updates' do
      it { is_expected.to be_nil }
    end
  end

  describe '.applicable_download_date_range' do
    it_behaves_like 'an applicable download date range', :taric_update do
      subject(:applicable_download_date_range) { described_class.applicable_download_date_range(initial_date: Date.new(2012, 6, 6)) }

      let(:initial_date) { Date.new(2012, 6, 6) }
    end
  end

  describe '#perform' do
    it 'emits a download_started instrumentation event' do
      allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform)
        .with('http://example.com/taric/TARIC320100101').and_return(build(:response, :not_found))

      allow(TariffSynchronizer::Instrumentation).to receive(:download_started)

      described_class.new(example_date).perform
      expect(TariffSynchronizer::Instrumentation).to have_received(:download_started)
    end

    it 'Calls the external server to download file' do
      allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform)
        .with('http://example.com/taric/TARIC320100101').and_return(build(:response, :not_found))
      described_class.new(example_date).perform

      expect(TariffSynchronizer::TariffUpdatesRequester).to have_received(:perform)
                                                             .with('http://example.com/taric/TARIC320100101')
    end

    context 'when successful response' do
      before do
        allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform)
                                                               .with('http://example.com/taric/TARIC320100101')
                                                               .and_return(build(:response, :success, content: "ABC.xml\nXYZ.xml"))
      end

      it 'Calls TariffDownloader perform for each TARIC update file found' do
        downloader = instance_spy(TariffSynchronizer::TariffDownloader, perform: true)

        ['ABC.xml', 'XYZ.xml'].each do |filename|
          allow(TariffSynchronizer::TariffDownloader).to receive(:new)
                                                           .with("2010-01-01_#{filename}", "http://example.com/taric/#{filename}", example_date, TariffSynchronizer::TaricUpdate)
                                                           .and_return(downloader)
        end

        described_class.new(example_date).perform

        ['ABC.xml', 'XYZ.xml'].each do |filename|
          expect(TariffSynchronizer::TariffDownloader).to have_received(:new)
                                                            .with("2010-01-01_#{filename}", "http://example.com/taric/#{filename}", example_date, TariffSynchronizer::TaricUpdate)
        end
      end
    end

    context 'with missing response' do
      before do
        allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform)
          .with('http://example.com/taric/TARIC320100101').and_return(build(:response, :not_found))
      end

      it { expect { described_class.new(example_date).perform }.not_to change(TariffSynchronizer::TaricUpdate, :count) }
    end

    context 'with retries exceeded response' do
      subject(:taric_update) { TariffSynchronizer::TaricUpdate.last }

      before do
        allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform)
          .with('http://example.com/taric/TARIC320100101').and_return(build(:response, :retry_exceeded))
      end

      it 'Creates a record' do
        expect {
          described_class.new(example_date).perform
        }.to change(TariffSynchronizer::TaricUpdate, :count).by(1)
      end

      it 'Creates a record with a failed state filename' do
        described_class.new(example_date).perform
        expect(taric_update.filename).to eq('2010-01-01_taric')
      end

      it 'Creates a record with a failed state file size' do
        described_class.new(example_date).perform
        expect(taric_update.filesize).to be_nil
      end

      it 'Creates a record with a failed state issue date' do
        described_class.new(example_date).perform
        expect(taric_update.issue_date).to eq(example_date)
      end

      it 'Creates a record with a failed state' do
        described_class.new(example_date).perform
        expect(taric_update.state).to eq(TariffSynchronizer::BaseUpdate::FAILED_STATE)
      end
    end

    context 'when retries exceeded response' do
      before do
        allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform)
                                                               .with('http://example.com/taric/TARIC320100101').and_return(build(:response, :retry_exceeded))
      end

      it 'emits a download_retry_exhausted instrumentation event' do
        allow(TariffSynchronizer::Instrumentation).to receive(:download_retry_exhausted)

        described_class.new(example_date).perform

        expect(TariffSynchronizer::Instrumentation).to have_received(:download_retry_exhausted)
      end

      it 'Sends a warning email' do
        ActionMailer::Base.deliveries.clear
        described_class.new(example_date).perform
        email = ActionMailer::Base.deliveries.last
        expect(email.encoded).to match(/Retry count exceeded/)
      end
    end

    context 'when blank response' do
      subject(:taric_update) { TariffSynchronizer::TaricUpdate.last }

      before do
        allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform)
          .with('http://example.com/taric/TARIC320100101').and_return(build(:response, :blank))
      end

      it 'Creates a record' do
        expect { described_class.new(example_date).perform }.to change(TariffSynchronizer::TaricUpdate, :count).by(1)
      end

      it 'Creates a record with a missing state with filename' do
        described_class.new(example_date).perform
        expect(taric_update.filename).to eq('2010-01-01_taric')
      end

      it 'Creates a record with a missing state with file size' do
        described_class.new(example_date).perform
        expect(taric_update.filesize).to be_nil
      end

      it 'Creates a record with a missing state with issue date' do
        described_class.new(example_date).perform
        expect(taric_update.issue_date).to eq(example_date)
      end

      it 'Creates a record with a missing state' do
        described_class.new(example_date).perform
        expect(taric_update.state).to eq(TariffSynchronizer::BaseUpdate::FAILED_STATE)
      end
    end

    context 'when perform with blank response' do
      before do
        allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform)
                                                               .with('http://example.com/taric/TARIC320100101').and_return(build(:response, :blank))
      end

      it 'emits a download_failed instrumentation event' do
        allow(TariffSynchronizer::Instrumentation).to receive(:download_failed)

        described_class.new(example_date).perform

        expect(TariffSynchronizer::Instrumentation).to have_received(:download_failed)
      end

      it 'Sends a warning email' do
        ActionMailer::Base.deliveries.clear
        described_class.new(example_date).perform
        email = ActionMailer::Base.deliveries.last
        expect(email.encoded).to match(/Received a blank file/)
      end
    end
  end
end
