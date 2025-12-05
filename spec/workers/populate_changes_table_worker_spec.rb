RSpec.describe PopulateChangesTableWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:package) { instance_double(Axlsx::Package) }
  let(:mailer) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

  before do
    allow(ChangesTablePopulator).to receive(:populate)
    allow(ChangesTablePopulator).to receive(:cleanup_outdated)
    allow(TariffChangesService).to receive(:generate)
    allow(TariffChangesService).to receive(:generate_report_for).and_return(package)
    allow(ReportsMailer).to receive(:commodity_watchlist).and_return(mailer)
    worker.perform
  end

  describe '#perform' do
    it { expect(ChangesTablePopulator).to have_received(:populate) }
    it { expect(ChangesTablePopulator).to have_received(:cleanup_outdated) }
    it { expect(TariffChangesService).to have_received(:generate) }

    it 'generates report for yesterday and sends email' do
      expect(TariffChangesService).to have_received(:generate_report_for).with(Time.zone.yesterday)
      expect(ReportsMailer).to have_received(:commodity_watchlist).with(Time.zone.yesterday, package)
    end
  end
end
