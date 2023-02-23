RSpec.describe RollbackWorker, type: :worker do
  let(:date) { '01-01-2020' }

  before do
    allow(GoodsNomenclatures::TreeNode).to receive(:refresh!).and_call_original
  end

  describe '#perform' do
    context 'for all envs' do
      before do
        allow(PaasConfig).to receive(:space).and_return('test')
      end

      it 'invokes rollback' do
        expect(TariffSynchronizer).to receive(:rollback).with(date, keep: false)
        expect(TariffSynchronizer).not_to receive(:rollback_cds)
        described_class.new.perform(date)
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

      it 'invokes rollback_cds' do
        expect(TariffSynchronizer).to receive(:rollback_cds).with(date, keep: false)
        expect(TariffSynchronizer).not_to receive(:rollback)
        described_class.new.perform(date)
      end

      it 'refreshes materialized view' do
        described_class.new.perform(date)

        expect(GoodsNomenclatures::TreeNode).to have_received(:refresh!)
      end
    end
  end
end
