RSpec.describe ApplyWorker, type: :worker do
  describe '#perform' do
    subject(:perform) { described_class.new.perform }

    before do
      allow(CdsSynchronizer).to receive(:apply)
      allow(TaricSynchronizer).to receive(:apply)
      allow(MaterializeViewHelper).to receive(:refresh_materialized_view)
      allow(ClearCacheWorker).to receive(:perform_async)
      allow(TradeTariffBackend).to receive(:service).and_return(service)
    end

    context 'when on the uk service' do
      let(:service) { 'uk' }

      before { perform }

      it { expect(CdsSynchronizer).to have_received(:apply) }
      it { expect(MaterializeViewHelper).to have_received(:refresh_materialized_view) }
      it { expect(ClearCacheWorker).to have_received(:perform_async) }
    end

    context 'when on the xi service' do
      let(:service) { 'xi' }

      before { perform }

      it { expect(TaricSynchronizer).to have_received(:apply) }
      it { expect(MaterializeViewHelper).to have_received(:refresh_materialized_view) }
      it { expect(ClearCacheWorker).to have_received(:perform_async) }
    end

    context 'when an error is raised' do
      let(:service) { 'uk' }

      before { allow(CdsSynchronizer).to receive(:apply).and_raise(StandardError, 'apply failed') }

      it { expect { perform }.to raise_error(StandardError, 'apply failed') }
    end
  end
end
