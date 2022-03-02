RSpec.describe TaricUpdatesWorker, type: :worker do
  describe '#perform' do
    subject(:perform) { described_class.new.perform }

    before do
      allow($stdout).to receive(:write)

      allow(TaricSynchronizer).to receive(:download)
      allow(TaricSynchronizer).to receive(:apply)
    end

    context 'when on the xi service' do
      before { perform }

      it { expect(TaricSynchronizer).to have_received(:download) }
      it { expect(TaricSynchronizer).to have_received(:apply).with(reindex_all_indexes: true) }
    end
  end
end
