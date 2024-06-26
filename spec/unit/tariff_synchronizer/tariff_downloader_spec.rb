RSpec.describe TariffSynchronizer::TariffDownloader do
  describe '#perform' do
    subject(:perform) { described_class.new(filename, url, date, update_klass).perform }

    let(:filename) { 'foo.xml.gzip' }
    let(:url) { 'https://example.com/download-the-file' }
    let(:date) { Date.current }
    let(:update_klass) { TariffSynchronizer::CdsUpdate }

    context 'when any part of the download process propagates an exception' do
      before do
        allow(TariffSynchronizer::TariffUpdatesRequester)
          .to receive(:perform)
          .with(url)
          .and_raise(StandardError, 'Something went wrong')
      end

      let(:response) { build(:response, :not_found) }

      it { expect { perform }.to change { update_klass.where(state: TariffSynchronizer::BaseUpdate::FAILED_STATE).count }.by(1) }
    end

    context 'when the file is already downloaded' do
      before do
        allow(TariffSynchronizer::FileService).to receive(:file_exists?).with('tmp/data/cds/foo.xml.gzip').and_return(true)
        allow(TariffSynchronizer::FileService).to receive(:file_size).with('tmp/data/cds/foo.xml.gzip').and_return(1)
        allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform).with(url)
      end

      context 'when an update already exists' do
        before do
          create(:cds_update, :pending, filename:, issue_date: date, filesize: 1)
        end

        it { expect { perform }.not_to change(update_klass, :count) }

        it 'does not request to download the file' do
          perform
          expect(TariffSynchronizer::TariffUpdatesRequester).not_to have_received(:perform)
        end
      end

      context 'when an does not yet exists' do
        it { expect { perform }.to change(update_klass, :count).by(1) }

        it 'does not request to download the file' do
          perform
          expect(TariffSynchronizer::TariffUpdatesRequester).not_to have_received(:perform)
        end
      end
    end

    context 'when the file has not been downloaded yet' do
      before do
        allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform).with(url).and_return(response)
      end

      context 'when the download response is empty' do
        let(:response) { build(:response, :blank) }

        it 'creates a failed update' do
          expect { perform }
            .to change { update_klass.where(state: TariffSynchronizer::BaseUpdate::FAILED_STATE).count }
            .by(1)
        end
      end

      context 'when the download response is retry exceeded' do
        let(:response) { build(:response, :retry_exceeded) }

        it 'creates a failed update' do
          expect { perform }
            .to change { update_klass.where(state: TariffSynchronizer::BaseUpdate::FAILED_STATE).count }
            .by(1)
        end
      end

      context 'when the download response is not found' do
        let(:response) { build(:response, :not_found) }

        it { expect { perform }.not_to change(update_klass, :count) }
      end

      context 'when the download response is successful' do
        before do
          allow(TariffSynchronizer::FileService).to receive(:write_file).with("tmp/data/#{update_klass.update_type}/foo.xml.gzip", be_a(String))
        end

        context 'when the response body is a valid ZIP file' do
          let(:response) { build(:response, :success_cds) }

          it 'creates a pending update' do
            expect { perform }
              .to change { update_klass.where(state: TariffSynchronizer::BaseUpdate::PENDING_STATE).count }
              .by(1)
          end

          it 'writes using the FileService' do
            perform
            expect(TariffSynchronizer::FileService).to have_received(:write_file).with('tmp/data/cds/foo.xml.gzip', be_a(String))
          end
        end

        context 'when the response body is not a ZIP file and the update type is Taric' do
          let(:response) { build(:response, :success, content: 'not_a_zip_file') }
          let(:update_klass) { TariffSynchronizer::TaricUpdate }

          it 'creates a pending update' do
            expect { perform }
              .to change { update_klass.where(state: TariffSynchronizer::BaseUpdate::PENDING_STATE).count }
              .by(1)
          end

          it 'writes using the FileService' do
            perform
            expect(TariffSynchronizer::FileService).to have_received(:write_file).with('tmp/data/taric/foo.xml.gzip', 'not_a_zip_file')
          end
        end

        context 'when the response body is not a ZIP file and the update type is CDS' do
          let(:response) { build(:response, :success, content: 'not_a_zip_file') }
          let(:update_klass) { TariffSynchronizer::CdsUpdate }

          it 'creates a failed update' do
            expect { perform }
              .to change { update_klass.where(state: TariffSynchronizer::BaseUpdate::FAILED_STATE).count }
              .by(1)
          end

          it 'persists the exception for review' do
            perform
            update = update_klass.find(filename:, update_type: update_klass.name, issue_date: date)
            expect(update.exception_class).to include('TariffDownloaderZipError')
          end

          it 'does not write using the FileService' do
            perform
            expect(TariffSynchronizer::FileService).not_to have_received(:write_file)
          end
        end
      end
    end
  end
end
