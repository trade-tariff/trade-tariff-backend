RSpec.describe RelabelGoodsNomenclatureWorker, type: :worker do
  describe '#perform' do
    before do
      allow(GoodsNomenclatureLabel).to receive_messages(goods_nomenclatures_dataset: instance_double(Sequel::Dataset, count: record_count), goods_nomenclature_label_total_pages: (record_count / 10.0).ceil)
      allow(RelabelGoodsNomenclaturePageWorker).to receive(:perform_async).and_call_original
    end

    context 'when there are 25 records' do
      let(:record_count) { 25 }

      it 'enqueues 3 page workers' do
        described_class.new.perform

        expect(RelabelGoodsNomenclaturePageWorker).to have_received(:perform_async).with(1)
        expect(RelabelGoodsNomenclaturePageWorker).to have_received(:perform_async).with(2)
        expect(RelabelGoodsNomenclaturePageWorker).to have_received(:perform_async).with(3)
      end

      it 'instruments generation started' do
        allow(LabelGenerator::Instrumentation).to receive(:generation_started)
        allow(LabelGenerator::Instrumentation).to receive(:generation_completed).and_call_original

        described_class.new.perform

        expect(LabelGenerator::Instrumentation).to have_received(:generation_started).with(
          total_pages: 3,
          page_size: described_class::PAGE_SIZE,
          total_records: 25,
        )
      end
    end

    context 'when there are exactly 10 records' do
      let(:record_count) { 10 }

      it 'enqueues 1 page worker' do
        described_class.new.perform

        expect(RelabelGoodsNomenclaturePageWorker).to have_received(:perform_async).with(1)
        expect(RelabelGoodsNomenclaturePageWorker).to have_received(:perform_async).once
      end
    end

    context 'when there are no records' do
      let(:record_count) { 0 }

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
