RSpec.describe GenerateSelfTextWorker, type: :worker do
  describe '#perform' do
    before do
      TradeTariffRequest.time_machine_now = Time.current

      allow(GenerateSelfTextChapterWorker).to receive(:perform_async)
      allow(SelfTextGenerator::Instrumentation).to receive(:generation_started)
    end

    context 'when chapters have stale self-texts' do
      let!(:chapter_with_work) do
        create(:chapter, :actual, goods_nomenclature_item_id: '0100000000')
      end
      let!(:chapter_without_work) do
        create(:chapter, :actual, goods_nomenclature_item_id: '0200000000')
      end

      before do
        gn_stale = create(:goods_nomenclature, :actual,
                          goods_nomenclature_item_id: '0101210000',
                          producline_suffix: '80')
        create(:goods_nomenclature_self_text, :stale, goods_nomenclature: gn_stale)

        gn_fresh = create(:goods_nomenclature, :actual,
                          goods_nomenclature_item_id: '0201210000',
                          producline_suffix: '80')
        create(:goods_nomenclature_self_text, goods_nomenclature: gn_fresh)
      end

      it 'only enqueues chapters with stale self-texts' do
        described_class.new.perform

        expect(GenerateSelfTextChapterWorker).to have_received(:perform_async)
          .with(chapter_with_work.goods_nomenclature_sid)
        expect(GenerateSelfTextChapterWorker).not_to have_received(:perform_async)
          .with(chapter_without_work.goods_nomenclature_sid)
      end

      it 'sets the Redis counter to the number of chapters needing work' do
        described_class.new.perform

        expect(TradeTariffBackend.redis.get(described_class::REDIS_KEY).to_i).to eq(1)
      end

      it 'instruments generation_started with filtered count' do
        described_class.new.perform

        expect(SelfTextGenerator::Instrumentation).to have_received(:generation_started)
          .with(total_chapters: 1)
      end
    end

    context 'when chapters have missing self-texts' do
      let!(:chapter) do
        create(:chapter, :actual, goods_nomenclature_item_id: '0300000000')
      end

      before do
        create(:goods_nomenclature, :actual,
               goods_nomenclature_item_id: '0301210000',
               producline_suffix: '80')
      end

      it 'enqueues the chapter' do
        described_class.new.perform

        expect(GenerateSelfTextChapterWorker).to have_received(:perform_async)
          .with(chapter.goods_nomenclature_sid)
      end
    end

    context 'when goods nomenclature is hidden' do
      before do
        create(:chapter, :actual, goods_nomenclature_item_id: '0500000000')
        gn = create(:goods_nomenclature, :actual,
                    goods_nomenclature_item_id: '0501210000',
                    producline_suffix: '80')
        create(:hidden_goods_nomenclature,
               goods_nomenclature_item_id: gn.goods_nomenclature_item_id)
      end

      it 'does not enqueue the chapter' do
        described_class.new.perform

        expect(GenerateSelfTextChapterWorker).not_to have_received(:perform_async)
      end
    end

    context 'when no chapters need work' do
      before do
        create(:chapter, :actual, goods_nomenclature_item_id: '0400000000')
        gn = create(:goods_nomenclature, :actual,
                    goods_nomenclature_item_id: '0401210000',
                    producline_suffix: '80')
        create(:goods_nomenclature_self_text, goods_nomenclature: gn)
      end

      it 'does not enqueue any chapter workers' do
        described_class.new.perform

        expect(GenerateSelfTextChapterWorker).not_to have_received(:perform_async)
      end

      it 'sets the Redis counter to zero' do
        described_class.new.perform

        expect(TradeTariffBackend.redis.get(described_class::REDIS_KEY).to_i).to eq(0)
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
