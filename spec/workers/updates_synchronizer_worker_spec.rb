RSpec.describe UpdatesSynchronizerWorker, type: :worker do
  describe '#perform' do
    subject(:perform) { described_class.new.perform }

    before do
      allow($stdout).to receive(:write)

      allow(TariffSynchronizer).to receive(:download)
      allow(TariffSynchronizer).to receive(:apply)
      allow(TariffSynchronizer).to receive(:download_cds)
      allow(TariffSynchronizer).to receive(:apply_cds)

      allow(TradeTariffBackend).to receive(:service).and_return(service)

      perform
    end

    context 'when on the xi service' do
      let(:service) { 'xi' }

      it { expect(TariffSynchronizer).to have_received(:download) }
      it { expect(TariffSynchronizer).to have_received(:apply).with(reindex_all_indexes: true) }

      it { expect(TariffSynchronizer).not_to have_received(:download_cds) }
      it { expect(TariffSynchronizer).not_to have_received(:apply_cds) }
    end

    context 'when on the uk service' do
      let(:service) { 'uk' }

      it { expect(TariffSynchronizer).to have_received(:download_cds) }
      it { expect(TariffSynchronizer).to have_received(:apply_cds) }

      it { expect(TariffSynchronizer).not_to have_received(:download) }
      it { expect(TariffSynchronizer).not_to have_received(:apply) }
    end
  end
end
