RSpec.describe PopulateTariffChangesWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:uk_worker) { true }

  before do
    allow(TariffChangesService).to receive(:generate)
    allow(MyCommoditiesSubscriptionWorker).to receive(:perform_async)
    allow(RefreshActiveCommoditiesCacheWorker).to receive(:perform_async)
    allow(TariffChange).to receive(:min).and_return(Time.zone.yesterday)
    allow(TariffChangesJobStatus).to receive(:pending_emails).and_return([Time.zone.yesterday])
    allow(TradeTariffBackend).to receive(:uk?).and_return(uk_worker)

    worker.perform
  end

  describe '#perform' do
    context 'when UK service' do
      it 'generates tariff changes' do
        expect(TariffChangesService).to have_received(:generate)
      end

      it 'performs async commodity subscription worker' do
        expect(MyCommoditiesSubscriptionWorker).to have_received(:perform_async).with(Time.zone.yesterday.to_s)
      end

      it 'refreshes active commodities cache' do
        expect(RefreshActiveCommoditiesCacheWorker).to have_received(:perform_async)
      end
    end

    context 'when not UK service' do
      let(:uk_worker) { false }

      it 'does not generate tariff changes' do
        expect(TariffChangesService).not_to have_received(:generate)
      end

      it 'does not perform async commodity subscription worker' do
        expect(MyCommoditiesSubscriptionWorker).not_to have_received(:perform_async)
      end

      it 'does not refresh active commodities cache' do
        expect(RefreshActiveCommoditiesCacheWorker).not_to have_received(:perform_async)
      end
    end
  end
end
