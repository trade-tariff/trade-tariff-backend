RSpec.describe ApplyWorker, type: :worker do
  describe '#perform' do
    subject(:perform) { described_class.new.perform }

    before do
      allow(CdsSynchronizer).to receive(:apply)
      allow(TaricSynchronizer).to receive(:apply)
      allow(MaterializeViewHelper).to receive(:refresh_materialized_view)
      allow(ActiveSupport::Notifications).to receive(:instrument)
      allow(TariffSynchronizer::BaseUpdate).to receive(:oldest_pending).and_return(nil)
      allow(TradeTariffBackend).to receive(:service).and_return(service)
    end

    context 'when on the uk service' do
      let(:service) { 'uk' }

      before { perform }

      it { expect(CdsSynchronizer).to have_received(:apply) }
      it { expect(MaterializeViewHelper).to have_received(:refresh_materialized_view) }

      it 'fires the tariff updates applied event with service and oldest_pending_date' do
        expect(ActiveSupport::Notifications).to have_received(:instrument)
          .with(
            TradeTariffBackend::TariffUpdateEventListener::TARIFF_UPDATES_APPLIED,
            hash_including(service: 'uk', oldest_pending_date: Time.zone.today.iso8601),
          )
      end
    end

    context 'when on the xi service' do
      let(:service) { 'xi' }

      before { perform }

      it { expect(TaricSynchronizer).to have_received(:apply) }
      it { expect(MaterializeViewHelper).to have_received(:refresh_materialized_view) }

      it 'fires the tariff updates applied event with service and oldest_pending_date' do
        expect(ActiveSupport::Notifications).to have_received(:instrument)
          .with(
            TradeTariffBackend::TariffUpdateEventListener::TARIFF_UPDATES_APPLIED,
            hash_including(service: 'xi', oldest_pending_date: Time.zone.today.iso8601),
          )
      end
    end

    context 'when pending updates exist' do
      let(:service) { 'uk' }
      let(:pending_update) { instance_double(TariffSynchronizer::BaseUpdate, issue_date: Date.new(2024, 1, 15)) }

      before do
        allow(TariffSynchronizer::BaseUpdate).to receive(:oldest_pending).and_return(pending_update)
        perform
      end

      it 'uses the oldest pending date in the event payload' do
        expect(ActiveSupport::Notifications).to have_received(:instrument)
          .with(
            TradeTariffBackend::TariffUpdateEventListener::TARIFF_UPDATES_APPLIED,
            hash_including(oldest_pending_date: '2024-01-15'),
          )
      end
    end

    context 'when an error is raised' do
      let(:service) { 'uk' }

      before { allow(CdsSynchronizer).to receive(:apply).and_raise(StandardError, 'apply failed') }

      it { expect { perform }.to raise_error(StandardError, 'apply failed') }
    end
  end
end
