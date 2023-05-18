RSpec.describe ReportWorker, type: :worker do
  subject(:worker) { described_class.new }

  describe '#perform' do
    it 'calls Reporting::Basic.generate' do
      allow(Reporting::Basic).to receive(:generate)
      worker.perform
      expect(Reporting::Basic).to have_received(:generate)
    end

    it 'calls Reporting::DeclarableDuties.generate' do
      allow(Reporting::DeclarableDuties).to receive(:generate)
      worker.perform
      expect(Reporting::DeclarableDuties).to have_received(:generate)
    end
  end
end
