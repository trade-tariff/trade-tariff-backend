RSpec.describe RollbackWorker, type: :worker do
  let(:date) { Date.yesterday.iso8601 }

  before do
    allow(GoodsNomenclatures::TreeNode).to receive(:refresh!).and_call_original
  end

  describe '#perform' do
    context 'for all envs' do
      before do
        allow(PaasConfig).to receive(:space).and_return('test')
      end

      it 'calls rollback' do
        allow(TariffSynchronizer).to receive(:rollback)

        described_class.new.perform(date)

        expect(TariffSynchronizer).to have_received(:rollback).with(date, keep: false)
      end

      it 'does not call rollback_cds' do
        allow(TariffSynchronizer).to receive(:rollback_cds)

        described_class.new.perform(date)

        expect(TariffSynchronizer).not_to have_received(:rollback_cds)
      end

      it 'refreshes materialized view' do
        described_class.new.perform(date)

        expect(GoodsNomenclatures::TreeNode).to have_received(:refresh!)
      end
    end

    context 'for cds env' do
      before do
        allow(TradeTariffBackend).to receive(:use_cds?).and_return(true)
      end

      it 'calls rollback_cds' do
        allow(TariffSynchronizer).to receive(:rollback_cds)

        described_class.new.perform(date)

        expect(TariffSynchronizer).to have_received(:rollback_cds).with(date, keep: false)
      end

      it 'does not call rollback' do
        allow(TariffSynchronizer).to receive(:rollback)

        described_class.new.perform(date)

        expect(TariffSynchronizer).not_to have_received(:rollback)
      end

      it 'refreshes materialized view' do
        described_class.new.perform(date)

        expect(GoodsNomenclatures::TreeNode).to have_received(:refresh!)
      end
    end
  end
end
