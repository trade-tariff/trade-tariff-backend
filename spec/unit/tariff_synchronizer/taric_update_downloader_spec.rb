require 'tariff_synchronizer/tariff_downloader'

describe TariffSynchronizer::TaricUpdateDownloader do
  let(:example_date) { Date.new(2010, 1, 1) }

  describe '#perform' do
    let(:generator) { TariffSynchronizer::TaricFileNameGenerator.new(example_date) }

    it 'Logs the request for the TaricUpdate file' do
      expect(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform)
        .with(generator.url).and_return(build(:response, :not_found))
      tariff_synchronizer_logger_listener
      described_class.new(example_date).perform
      expect(@logger.logged(:info).size).to eq 1
      expect(@logger.logged(:info).last).to eq("Checking for TARIC update for #{example_date} at #{generator.url}")
    end

    it 'Calls the external server to download file' do
      expect(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform)
        .with(generator.url).and_return(build(:response, :not_found))
      described_class.new(example_date).perform
    end

    context 'Successful Response' do
      before do
        allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform)
          .with(generator.url).and_return(build(:response, :success, content: "ABC.xml\nXYZ.xml"))
      end

      it 'Calls TariffDownloader perform for each TARIC update file found' do
        downlader = instance_double('TariffSynchronizer::TariffDownloader', perform: true)

        ['ABC.xml', 'XYZ.xml'].each do |filename|
          expect(TariffSynchronizer::TariffDownloader).to receive(:new)
            .with("2010-01-01_#{filename}", "http://example.com/taric/#{filename}", example_date, TariffSynchronizer::TaricUpdate)
            .and_return(downlader)
        end

        described_class.new(example_date).perform
      end
    end

    context 'Missing Response' do
      before do
        allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform)
          .with(generator.url).and_return(build(:response, :not_found))
      end

      it 'Creates a record with a missing state if the date has passed' do
        expect {
          described_class.new(example_date).perform
        }.to change(TariffSynchronizer::TaricUpdate, :count).by(1)

        taric_update = TariffSynchronizer::TaricUpdate.last
        expect(taric_update.filename).to eq('2010-01-01_taric')
        expect(taric_update.filesize).to be_nil
        expect(taric_update.issue_date).to eq(example_date)
        expect(taric_update.state).to eq(TariffSynchronizer::BaseUpdate::MISSING_STATE)
      end

      it "Doesn't create a record if the date is the same" do
        expect {
          travel_to example_date do
            described_class.new(example_date).perform
          end
        }.not_to change(TariffSynchronizer::TaricUpdate, :count)
      end

      it 'Logs the creating of the TaricUpdate record with missing state' do
        tariff_synchronizer_logger_listener
        described_class.new(example_date).perform
        expect(@logger.logged(:warn).size).to eq 1
        expect(@logger.logged(:warn).last).to eq('Update NOT found for 2010-01-01 at http://example.com/taric/TARIC320100101')
      end
    end

    context 'Retries Exceeded Response' do
      before do
        allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform)
          .with(generator.url).and_return(build(:response, :retry_exceeded))
      end

      it 'Creates a record with a failed state' do
        expect {
          described_class.new(example_date).perform
        }.to change(TariffSynchronizer::TaricUpdate, :count).by(1)

        taric_update = TariffSynchronizer::TaricUpdate.last
        expect(taric_update.filename).to eq('2010-01-01_taric')
        expect(taric_update.filesize).to be_nil
        expect(taric_update.issue_date).to eq(example_date)
        expect(taric_update.state).to eq(TariffSynchronizer::BaseUpdate::FAILED_STATE)
      end

      it 'Logs the creating of the TaricUpdate record with failed state' do
        tariff_synchronizer_logger_listener
        described_class.new(example_date).perform
        expect(@logger.logged(:warn).size).to eq 1
        expect(@logger.logged(:warn).last).to eq('Download retry count exceeded for http://example.com/taric/TARIC320100101')
      end

      it 'Sends a warning email' do
        ActionMailer::Base.deliveries.clear
        described_class.new(example_date).perform
        email = ActionMailer::Base.deliveries.last
        expect(email.encoded).to match(/Retry count exceeded/)
      end
    end

    context 'Blank Response' do
      before do
        allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform)
          .with(generator.url).and_return(build(:response, :blank))
      end

      it 'Creates a record with a missing state' do
        expect {
          described_class.new(example_date).perform
        }.to change(TariffSynchronizer::TaricUpdate, :count).by(1)

        taric_update = TariffSynchronizer::TaricUpdate.last
        expect(taric_update.filename).to eq('2010-01-01_taric')
        expect(taric_update.filesize).to be_nil
        expect(taric_update.issue_date).to eq(example_date)
        expect(taric_update.state).to eq(TariffSynchronizer::BaseUpdate::FAILED_STATE)
      end

      it 'Logs the creating of the TaricUpdate record with failed state' do
        tariff_synchronizer_logger_listener
        described_class.new(example_date).perform
        expect(@logger.logged(:error).size).to eq 1
        expect(@logger.logged(:error).last).to eq('Blank update content received for 2010-01-01: http://example.com/taric/TARIC320100101')
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
