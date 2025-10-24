RSpec.describe PopulateChangesTableWorker, type: :worker do
  subject(:worker) { described_class.new }

  before do
    allow(ChangesTablePopulator).to receive(:populate)
    allow(ChangesTablePopulator).to receive(:cleanup_outdated)
    allow(TariffChangesService).to receive(:generate)
    allow(TariffChangesService).to receive(:populate_backlog)
    allow(DeltaReportService).to receive(:generate)
    worker.perform
  end

  describe '#perform' do
    it { expect(ChangesTablePopulator).to have_received(:populate) }
    it { expect(ChangesTablePopulator).to have_received(:cleanup_outdated) }
    it { expect(TariffChangesService).to have_received(:populate_backlog) }
    it { expect(DeltaReportService).to have_received(:generate) }

    context 'when TariffChange records already exist' do
      before do
        allow(TariffChange).to receive(:count).and_return(10)
        worker.perform
      end

      it { expect(TariffChangesService).to have_received(:generate) }
    end
  end
end
