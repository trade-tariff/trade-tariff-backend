RSpec.describe TariffSynchronizer::TaricUpdateDownloaderPatched do
  subject(:update_downloader) { described_class.new(taric_update) }

  before do
    tariff_downloader = instance_double(TariffSynchronizer::TariffDownloader, perform: nil)

    allow(tariff_downloader).to receive(:success?).and_return(true, false, true)

    allow(TariffSynchronizer::TariffDownloader).to receive(:new).and_return(tariff_downloader)
  end

  describe '#perform' do
    context 'when the update already exists in the database' do
      let(:taric_update) { create(:taric_update, example_date: Date.parse('2022-01-24')) }

      it 'does not call the TariffDownloader' do
        update_downloader.perform

        expect(TariffSynchronizer::TariffDownloader).not_to have_received(:new)
      end
    end

    context 'when the update does not yet exist in the database' do
      let(:taric_update) { build(:taric_update, example_date: Date.parse('2022-01-24')) }

      it 'calls the TariffDownloader until the next not found update' do
        update_downloader.perform

        # successful update
        expect(TariffSynchronizer::TariffDownloader).to have_received(:new).with(
          '2022-01-24_TGB22024.xml',
          'http://example.com/taric/TGB22024.xml',
          Date.parse('2022-01-24'),
          TariffSynchronizer::TaricUpdate,
        ).once.ordered

        # unsuccessful update
        expect(TariffSynchronizer::TariffDownloader).to have_received(:new).with(
          '2022-01-25_TGB22025.xml',
          'http://example.com/taric/TGB22025.xml',
          Date.parse('2022-01-25'),
          TariffSynchronizer::TaricUpdate,
        ).once.ordered

        # successful rollover update
        expect(TariffSynchronizer::TariffDownloader).to have_received(:new).with(
          '2023-01-01_TGB23001.xml',
          'http://example.com/taric/TGB23001.xml',
          Date.parse('2023-01-01'),
          TariffSynchronizer::TaricUpdate,
        ).once.ordered
      end
      # rubocop:enable RSpec/MultipleExpectations
    end
  end
end
