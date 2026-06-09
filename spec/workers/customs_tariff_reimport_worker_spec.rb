RSpec.describe CustomsTariffReimportWorker do
  describe '#perform' do
    it 'calls Reimporter with the given version' do
      reimporter = instance_double(CustomsTariffImporter::Reimporter)
      allow(CustomsTariffImporter::Reimporter).to receive(:new).and_return(reimporter)
      allow(reimporter).to receive(:call)

      described_class.new.perform('1.31')

      expect(reimporter).to have_received(:call).with(version: '1.31')
    end
  end
end
