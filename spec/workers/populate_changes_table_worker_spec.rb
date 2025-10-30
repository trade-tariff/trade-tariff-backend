RSpec.describe PopulateChangesTableWorker, type: :worker do
  subject(:worker) { described_class.new }

  before do
    allow(ChangesTablePopulator).to receive(:populate)
    allow(ChangesTablePopulator).to receive(:cleanup_outdated)
    allow(TariffChangesService).to receive(:generate)
    allow(TariffChangesService).to receive(:generate_report_for)
    allow(DeltaReportService).to receive(:generate)
    worker.perform
  end

  describe '#perform' do
    it { expect(ChangesTablePopulator).to have_received(:populate) }
    it { expect(ChangesTablePopulator).to have_received(:cleanup_outdated) }
    it { expect(TariffChangesService).to have_received(:generate) }
    it { expect(TariffChangesService).to have_received(:generate_report_for).with(Time.zone.yesterday) }
    it { expect(DeltaReportService).to have_received(:generate) }
  end
end
