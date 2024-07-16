RSpec.describe TariffSynchronizer::TaricUpdateDownloader do
  let(:example_date) { Date.new(2010, 1, 1) }

  describe '#perform' do
    it 'Logs the request for the TaricUpdate file' do
      allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform)
        .with('http://example.com/taric/TARIC320100101').and_return(build(:response, :not_found))

      allow(Rails.logger).to receive(:info)

      described_class.new(example_date).perform
      expect(Rails.logger).to have_received(:info).with("Checking for TARIC update for #{example_date} at http://example.com/taric/TARIC320100101")
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

      it 'Logs the creating of the TaricUpdate record with failed state' do
        allow(Rails.logger).to receive(:warn)

        described_class.new(example_date).perform

        expect(Rails.logger).to have_received(:warn).with('Download retry count exceeded for http://example.com/taric/TARIC320100101')
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

      it 'Logs the creating of the TaricUpdate record with failed state' do
        allow(Rails.logger).to receive(:error)

        described_class.new(example_date).perform

        expect(Rails.logger).to have_received(:error).with('Blank update content received for 2010-01-01: http://example.com/taric/TARIC320100101')
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
