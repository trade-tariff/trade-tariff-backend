RSpec.describe BasicReportWorker, type: :worker do
  subject(:worker) { described_class.new }

  describe '#perform' do
    it 'calls Reporting::Basic.generate' do
      allow(Reporting::Basic).to receive(:generate)
      worker.perform
      expect(Reporting::Basic).to have_received(:generate)
    end
  end
end
