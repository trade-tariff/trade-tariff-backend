RSpec.describe TradeTariffBackend::TariffUpdateEventListener do
  before do
    allow(ClearCacheWorker).to receive(:perform_async)
    allow(ClearInvalidSearchReferences).to receive(:perform_async)
    allow(TreeIntegrityCheckWorker).to receive(:perform_async)
    allow(PopulateChangesTableWorker).to receive(:perform_async)
    allow(GreenLanesUpdatesWorker).to receive(:perform_in)
    allow(PopulateTariffChangesWorker).to receive(:perform_async)
  end

  describe '.on_tariff_updates_applied' do
    context 'when service is uk' do
      before { described_class.on_tariff_updates_applied(service: 'uk') }

      it { expect(ClearCacheWorker).to have_received(:perform_async) }
      it { expect(ClearInvalidSearchReferences).to have_received(:perform_async) }
      it { expect(TreeIntegrityCheckWorker).to have_received(:perform_async) }
      it { expect(PopulateChangesTableWorker).to have_received(:perform_async) }
      it { expect(GreenLanesUpdatesWorker).not_to have_received(:perform_in) }
    end

    context 'when service is xi' do
      before { described_class.on_tariff_updates_applied(service: 'xi', oldest_pending_date: '2024-01-15') }

      it { expect(ClearCacheWorker).to have_received(:perform_async) }
      it { expect(ClearInvalidSearchReferences).to have_received(:perform_async) }
      it { expect(TreeIntegrityCheckWorker).to have_received(:perform_async) }
      it { expect(PopulateChangesTableWorker).to have_received(:perform_async) }
      it { expect(GreenLanesUpdatesWorker).to have_received(:perform_in).with(15.minutes, '2024-01-15') }
    end
  end

  describe '.on_tariff_cache_cleared' do
    context 'when service is uk' do
      before { described_class.on_tariff_cache_cleared(service: 'uk') }

      it { expect(PopulateTariffChangesWorker).to have_received(:perform_async) }
    end

    context 'when service is xi' do
      before { described_class.on_tariff_cache_cleared(service: 'xi') }

      it { expect(PopulateTariffChangesWorker).not_to have_received(:perform_async) }
    end
  end
end
