require 'rails_helper'
require 'tariff_synchronizer/tariff_downloader'

describe TariffSynchronizer::TariffDownloader do
  let(:example_date) { Date.new(2010, 1, 1) }

  describe '#perform' do
    context 'a CHIEF file' do
      let(:generator) { TariffSynchronizer::ChiefFileNameGenerator.new(example_date) }
      let(:chief_update_klass) { TariffSynchronizer::ChiefUpdate }
      let(:tariff_downloader) do
        described_class.new(
          generator.name,
          generator.url,
          example_date,
          chief_update_klass,
        )
      end

      context 'File already downloaded' do
        before do
          allow(tariff_downloader).to receive(:file_already_downloaded?).and_return(true)
          allow(tariff_downloader).to receive(:filesize).and_return(999)
        end

        it 'Do no create a ChiefUpdate record if this is already created' do
          create(:chief_update, filename: generator.name, issue_date: example_date)
          chief_update = chief_update_klass.last
          expect {
            tariff_downloader.perform
          }.not_to change(chief_update_klass, :count)
        end

        it 'Creates a ChiefUpdate record with a pending state' do
          expect {
            tariff_downloader.perform
          }.to change(chief_update_klass, :count).by(1)
          chief_update = chief_update_klass.last
          expect(chief_update.filename).to eq(generator.name)
          expect(chief_update.filesize).to eq(999)
          expect(chief_update.issue_date).to eq(example_date)
          expect(chief_update.state).to eq(TariffSynchronizer::BaseUpdate::PENDING_STATE)
        end

        it 'Logs the creating of the ChiefUpdate record' do
          tariff_synchronizer_logger_listener
          tariff_downloader.perform
          expect(@logger.logged(:info).size).to eq 1
          expect(@logger.logged(:info).last).to eq('Created/Updated CHIEF entry for 2010-01-01 and 2010-01-01_KBT009(10001).txt')
        end
      end

      context 'File is not yet downloaded' do
        before do
          allow(tariff_downloader).to receive(:file_already_downloaded?).and_return(false)
          allow(tariff_downloader).to receive(:filesize).and_return(999)
        end

        it 'Calls the external server to download file' do
          expect(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform)
            .with(generator.url).and_return(build(:response, :not_found))
          tariff_downloader.perform
        end

        context 'Successful Response' do
          before do
            allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform)
              .with(generator.url).and_return(build(:response, :success, content: 'abc'))

            # Let's assume 'abc' is a valid csv content
            allow(chief_update_klass).to receive(:validate_file!)
                                                  .and_return(true)
          end

          it 'Creates a record with a pending state' do
            # Let's stub the creation of the file
            allow(TariffSynchronizer::FileService).to receive(:write_file)

            expect {
              tariff_downloader.perform
            }.to change(chief_update_klass, :count).by(1)

            chief_update = chief_update_klass.last
            expect(chief_update.filename).to eq('2010-01-01_KBT009(10001).txt')
            expect(chief_update.filesize).to eq(3)
            expect(chief_update.issue_date).to eq(example_date)
            expect(chief_update.state).to eq(TariffSynchronizer::BaseUpdate::PENDING_STATE)
          end

          it 'Calls the write_file method to create the file' do
            path = "#{TariffSynchronizer.root_path}/chief/#{generator.name}"
            expect(TariffSynchronizer::FileService).to receive(:write_file).with(path, 'abc')
            tariff_downloader.perform
          end

          it 'Logs the creating of the ChiefUpdate record with missing state' do
            # Let's stub the creation of the file
            expect(TariffSynchronizer::FileService).to receive(:write_file)
            tariff_synchronizer_logger_listener

            tariff_downloader.perform
            expect(@logger.logged(:info).size).to eq 1
            expect(@logger.logged(:info).last).to eq('CHIEF update for 2010-01-01 downloaded from http://example.com/taric/KBT009(10001).txt, to tmp/data/chief/2010-01-01_KBT009(10001).txt (size: 3)')
          end
        end

        context 'Missing Response' do
          before do
            allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform)
              .with(generator.url).and_return(build(:response, :not_found))
          end

          it 'Creates a record with a missing state if the date has passed' do
            expect {
              tariff_downloader.perform
            }.to change(chief_update_klass, :count).by(1)

            chief_update = chief_update_klass.last
            expect(chief_update.filename).to eq('2010-01-01_chief')
            expect(chief_update.filesize).to be_nil
            expect(chief_update.issue_date).to eq(example_date)
            expect(chief_update.state).to eq(TariffSynchronizer::BaseUpdate::MISSING_STATE)
          end

          it "Doesn't create a record if the date is the same" do
            expect {
              travel_to example_date do
                tariff_downloader.perform
              end
            }.not_to change(chief_update_klass, :count)
          end

          it 'Logs the creating of the ChiefUpdate record with missing state' do
            tariff_synchronizer_logger_listener
            tariff_downloader.perform
            expect(@logger.logged(:warn).size).to eq 1
            expect(@logger.logged(:warn).last).to eq('Update NOT found for 2010-01-01 at http://example.com/taric/KBT009(10001).txt')
          end
        end

        context 'Retries Exceeded Response' do
          before do
            allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform)
              .with(generator.url).and_return(build(:response, :retry_exceeded))
          end

          it 'Creates a record with a failed state' do
            expect {
              tariff_downloader.perform
            }.to change(chief_update_klass, :count).by(1)

            chief_update = chief_update_klass.last
            expect(chief_update.filename).to eq('2010-01-01_KBT009(10001).txt')
            expect(chief_update.filesize).to be_nil
            expect(chief_update.issue_date).to eq(example_date)
            expect(chief_update.state).to eq(TariffSynchronizer::BaseUpdate::FAILED_STATE)
          end

          it 'Logs the creating of the ChiefUpdate record with failed state' do
            tariff_synchronizer_logger_listener
            tariff_downloader.perform
            expect(@logger.logged(:warn).size).to eq 1
            expect(@logger.logged(:warn).last).to eq('Download retry count exceeded for http://example.com/taric/KBT009(10001).txt')
          end

          it 'Sends a warning email' do
            ActionMailer::Base.deliveries.clear
            tariff_downloader.perform
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
              tariff_downloader.perform
            }.to change(chief_update_klass, :count).by(1)

            chief_update = chief_update_klass.last
            expect(chief_update.filename).to eq('2010-01-01_KBT009(10001).txt')
            expect(chief_update.filesize).to be_nil
            expect(chief_update.issue_date).to eq(example_date)
            expect(chief_update.state).to eq(TariffSynchronizer::BaseUpdate::FAILED_STATE)
          end

          it 'Logs the creating of the ChiefUpdate record with failed state' do
            tariff_synchronizer_logger_listener
            tariff_downloader.perform
            expect(@logger.logged(:error).size).to eq 1
            expect(@logger.logged(:error).last).to eq('Blank update content received for 2010-01-01: http://example.com/taric/KBT009(10001).txt')
          end

          it 'Sends a warning email' do
            ActionMailer::Base.deliveries.clear
            tariff_downloader.perform
            email = ActionMailer::Base.deliveries.last
            expect(email.encoded).to match(/Received a blank file/)
          end
        end
      end
    end
  end
end
