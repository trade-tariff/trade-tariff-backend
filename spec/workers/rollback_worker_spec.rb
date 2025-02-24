RSpec.describe RollbackWorker, type: :worker do
  let(:date) { Date.yesterday.iso8601 }

  before do
    allow(GoodsNomenclatures::TreeNode).to receive(:refresh!).and_call_original
  end

  describe '#perform' do
    context 'for xi' do
      before do
        allow(TradeTariffBackend).to receive(:service).and_return('xi')
        allow(TaricSynchronizer).to receive(:rollback).with(date, keep: false)
        allow(CdsSynchronizer).to receive(:rollback)
      end

      it 'invokes rollback' do
        described_class.new.perform(date)
        expect(TaricSynchronizer).to have_received(:rollback).with(date, keep: false)
      end

      it 'does not call rollback_cds' do
        described_class.new.perform(date)
        expect(CdsSynchronizer).not_to have_received(:rollback)
      end

      it 'refreshes materialized view' do
        described_class.new.perform(date)
        expect(GoodsNomenclatures::TreeNode).to have_received(:refresh!)
      end
    end

    context 'for uk' do
      before do
        allow(TradeTariffBackend).to receive_messages(service: 'uk')
        allow(TaricSynchronizer).to receive(:rollback)
        allow(CdsSynchronizer).to receive(:rollback).with(date, keep: false)
      end

      it 'invokes rollback' do
        described_class.new.perform(date)
        expect(CdsSynchronizer).to have_received(:rollback).with(date, keep: false)
      end

      it 'does not call rollback_cds' do
        described_class.new.perform(date)
        expect(TaricSynchronizer).not_to have_received(:rollback)
      end

      it 'refreshes materialized view' do
        described_class.new.perform(date)
        expect(GoodsNomenclatures::TreeNode).to have_received(:refresh!)
      end
    end
  end
end
