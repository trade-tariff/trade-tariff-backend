RSpec.describe PopulateChangesTableWorker, type: :worker do
  subject(:worker) { described_class.new }

  before do
    allow(ChangesTablePopulator).to receive(:populate)
    allow(ChangesTablePopulator).to receive(:cleanup_outdated)

    worker.perform
  end

  describe '#perform' do
    it { expect(ChangesTablePopulator).to have_received(:populate) }
    it { expect(ChangesTablePopulator).to have_received(:cleanup_outdated) }
  end
end
