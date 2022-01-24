RSpec.describe TariffSynchronizer::TaricUpdateDownloaderPatched do
  subject(:update_downloader) { described_class.new(taric_update) }

  before do
    tariff_downloader = instance_double('TariffSynchronizer::TariffDownloader', perform: nil)

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

      it 'calls the TariffDownloader' do
        update_downloader.perform

        expect(TariffSynchronizer::TariffDownloader).to have_received(:new).with(
          '2022-01-24_TGB22024.xml',
          'http://example.com/taric/TGB22024.xml',
          Date.parse('2022-01-24'),
          TariffSynchronizer::TaricUpdate,
        )
      end
    end
  end
end
