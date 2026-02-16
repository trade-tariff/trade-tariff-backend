RSpec.describe GenerateSelfTextWorker, type: :worker do
  describe '#perform' do
    let(:chapters) do
      [
        instance_double(Chapter, goods_nomenclature_sid: 1),
        instance_double(Chapter, goods_nomenclature_sid: 2),
        instance_double(Chapter, goods_nomenclature_sid: 3),
      ]
    end

    before do
      TradeTariffRequest.time_machine_now = Time.current

      allow(Chapter).to receive_message_chain(:actual, :all).and_return(chapters)
      allow(GenerateSelfTextChapterWorker).to receive(:perform_async)
      allow(SelfTextGenerator::Instrumentation).to receive(:generation_started)
    end

    it 'sets the Redis counter to the number of chapters' do
      described_class.new.perform

      expect(TradeTariffBackend.redis.get(described_class::REDIS_KEY).to_i).to eq(3)
    end

    it 'enqueues a chapter worker for each chapter' do
      described_class.new.perform

      chapters.each do |chapter|
        expect(GenerateSelfTextChapterWorker).to have_received(:perform_async)
          .with(chapter.goods_nomenclature_sid)
      end
    end

    it 'instruments generation_started' do
      described_class.new.perform

      expect(SelfTextGenerator::Instrumentation).to have_received(:generation_started)
        .with(total_chapters: 3)
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
