require 'rails_helper'

describe UpdatesSynchronizerWorker, type: :worker do
  before do
    allow($stdout).to receive(:write)
    allow(TariffSynchronizer).to receive(:download)
    allow(TariffSynchronizer).to receive(:apply)
    allow(TariffSynchronizer).to receive(:download_cds)
    allow(TariffSynchronizer).to receive(:apply_cds)
  end

  describe '#perform' do
    context 'when CDS flag is off' do
      before do
        allow(TradeTariffBackend).to receive(:use_cds?).and_return(false)
      end

      it 'invokes the apply/download for the XI service' do
        allow(TradeTariffBackend).to receive(:xi?).and_return(true)

        expect(TariffSynchronizer).to receive(:download)
        expect(TariffSynchronizer).to receive(:apply)
        expect(TariffSynchronizer).not_to receive(:download_cds)
        expect(TariffSynchronizer).not_to receive(:apply_cds)
        described_class.new.perform
      end

      it 'does not invoke any apply/download for the UK service' do
        allow(TradeTariffBackend).to receive(:uk?).and_return(true)

        expect(TariffSynchronizer).not_to receive(:download)
        expect(TariffSynchronizer).not_to receive(:apply)
        expect(TariffSynchronizer).not_to receive(:download_cds)
        expect(TariffSynchronizer).not_to receive(:apply_cds)
        described_class.new.perform
      end
    end

    context 'when CDS flag is on' do
      before do
        allow(TradeTariffBackend).to receive(:use_cds?).and_return(true)
      end

      it 'invokes rollback_cds' do
        expect(TariffSynchronizer).to receive(:download_cds)
        expect(TariffSynchronizer).to receive(:apply_cds)
        expect(TariffSynchronizer).not_to receive(:download)
        expect(TariffSynchronizer).not_to receive(:apply)
        described_class.new.perform
      end
    end
  end
end
