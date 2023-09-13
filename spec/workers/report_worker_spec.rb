RSpec.describe ReportWorker, type: :worker do
  subject(:worker) { described_class.new }

  describe '#perform' do
    before do
      allow(Reporting::Commodities).to receive(:generate)
      allow(Reporting::Basic).to receive(:generate)
      allow(Reporting::DeclarableDuties).to receive(:generate)
      allow(Reporting::GeographicalAreaGroups).to receive(:generate)
      allow(Reporting::Prohibitions).to receive(:generate)

      worker.perform
    end

    it { expect(Reporting::Commodities).to have_received(:generate) }
    it { expect(Reporting::Basic).to have_received(:generate) }
    it { expect(Reporting::DeclarableDuties).to have_received(:generate) }
    it { expect(Reporting::GeographicalAreaGroups).to have_received(:generate) }
    it { expect(Reporting::Prohibitions).to have_received(:generate) }
  end
end
