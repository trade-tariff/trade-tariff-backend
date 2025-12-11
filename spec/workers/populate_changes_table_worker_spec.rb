RSpec.describe PopulateChangesTableWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:package) { instance_double(Axlsx::Package) }
  let(:mailer) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }
  let(:uk_worker) { true }

  before do
    allow(ChangesTablePopulator).to receive(:populate)
    allow(ChangesTablePopulator).to receive(:cleanup_outdated)
    allow(TariffChangesService).to receive(:generate)
    allow(TariffChangesService).to receive(:generate_report_for).and_return(package)
    allow(MyCommoditiesSubscriptionWorker).to receive(:perform_async)
    allow(ReportsMailer).to receive(:commodity_watchlist).and_return(mailer)
    allow(TradeTariffBackend).to receive(:uk?).and_return(uk_worker)

    worker.perform
  end

  describe '#perform' do
    it { expect(ChangesTablePopulator).to have_received(:populate) }
    it { expect(ChangesTablePopulator).to have_received(:cleanup_outdated) }

    context 'when UK service' do
      it 'generates tariff changes' do
        expect(TariffChangesService).to have_received(:generate)
      end

      it 'performs async commodity subscription worker' do
        expect(MyCommoditiesSubscriptionWorker).to have_received(:perform_async)
      end

      it 'generates report for yesterday and sends email' do
        expect(TariffChangesService).to have_received(:generate_report_for).with(Time.zone.yesterday)
        expect(ReportsMailer).to have_received(:commodity_watchlist).with(Time.zone.yesterday, package)
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

      it 'does not generate report' do
        expect(TariffChangesService).not_to have_received(:generate_report_for)
      end
    end
  end
end
