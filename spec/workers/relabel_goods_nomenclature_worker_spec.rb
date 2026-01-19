RSpec.describe RelabelGoodsNomenclatureWorker, type: :worker do
  describe '#perform' do
    before do
      allow(GoodsNomenclatureLabel).to receive(:goods_nomenclatures_dataset).and_return(instance_double(Sequel::Dataset, count: record_count))
      allow(RelabelGoodsNomenclaturePageWorker).to receive(:perform_async).and_call_original
      allow(Rails.logger).to receive(:info).and_call_original
    end

    context 'when there are 25 records' do
      let(:record_count) { 25 }

      it 'enqueues 3 page workers' do
        described_class.new.perform

        expect(RelabelGoodsNomenclaturePageWorker).to have_received(:perform_async).with(1)
        expect(RelabelGoodsNomenclaturePageWorker).to have_received(:perform_async).with(2)
        expect(RelabelGoodsNomenclaturePageWorker).to have_received(:perform_async).with(3)
      end

      it 'logs the number of jobs enqueued' do
        described_class.new.perform

        expect(Rails.logger).to have_received(:info).with('Enqueued 3 relabelling jobs')
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
