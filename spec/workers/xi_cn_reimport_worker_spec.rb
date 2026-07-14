require 'rails_helper'

RSpec.describe XiCnReimportWorker do
  subject(:worker) { described_class.new }

  let(:reimporter_double) { instance_double(XiCnImporter::Reimporter, call: nil) }

  before do
    allow(TradeTariffBackend).to receive(:xi?).and_return(true)
    allow(XiCnImporter::Reimporter).to receive(:new).and_return(reimporter_double)
  end

  it 'calls the Reimporter with the given version' do
    worker.perform('32025R1926')
    expect(reimporter_double).to have_received(:call).with(version: '32025R1926')
  end

  context 'when SERVICE is not xi' do
    before { allow(TradeTariffBackend).to receive(:xi?).and_return(false) }

    it 'does nothing' do
      worker.perform('32025R1926')
      expect(reimporter_double).not_to have_received(:call)
    end
  end
end
