RSpec.describe RelabelGoodsNomenclatureWorker, type: :worker do
  describe '#perform' do
    before do
      dataset = instance_double(Sequel::Dataset, map: sids)
      allow(GoodsNomenclatureLabel).to receive(:goods_nomenclatures_dataset).and_return(dataset)
      allow(RelabelGoodsNomenclaturePageWorker).to receive(:perform_async).and_call_original
    end

    context 'when there are 25 records' do
      let(:sids) { (1..25).to_a }

      it 'enqueues 3 page workers with SID arrays and batch indices' do
        described_class.new.perform

        expect(RelabelGoodsNomenclaturePageWorker).to have_received(:perform_async).with(sids[0..9], 1)
        expect(RelabelGoodsNomenclaturePageWorker).to have_received(:perform_async).with(sids[10..19], 2)
        expect(RelabelGoodsNomenclaturePageWorker).to have_received(:perform_async).with(sids[20..24], 3)
      end

      it 'instruments generation started' do
        allow(LabelGenerator::Instrumentation).to receive(:generation_started)
        allow(LabelGenerator::Instrumentation).to receive(:generation_completed).and_call_original

        described_class.new.perform

        expect(LabelGenerator::Instrumentation).to have_received(:generation_started).with(
          total_pages: 3,
          page_size: TradeTariffBackend.goods_nomenclature_label_page_size,
          total_records: 25,
        )
      end
    end

    context 'when there are exactly 10 records' do
      let(:sids) { (1..10).to_a }

      it 'enqueues 1 page worker' do
        described_class.new.perform

        expect(RelabelGoodsNomenclaturePageWorker).to have_received(:perform_async).with(sids, 1)
        expect(RelabelGoodsNomenclaturePageWorker).to have_received(:perform_async).once
      end
    end

    context 'when there are no records' do
      let(:sids) { [] }

      it 'does not enqueue any page workers' do
        described_class.new.perform

        expect(RelabelGoodsNomenclaturePageWorker).not_to have_received(:perform_async)
      end
    end
  end

  describe 'sidekiq options' do
    it 'uses the sync queue' do
      expect(described_class.sidekiq_options['queue']).to eq(:sync)
    end

    it 'disables retries' do
      expect(described_class.sidekiq_options['retry']).to be(false)
    end
  end
end
