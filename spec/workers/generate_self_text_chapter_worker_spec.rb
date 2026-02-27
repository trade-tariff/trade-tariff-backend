RSpec.describe GenerateSelfTextChapterWorker, type: :worker do
  describe '#perform' do
    let(:chapter) { create(:chapter, :with_description) }
    let(:chapter_sid) { chapter.goods_nomenclature_sid }
    let(:mechanical_stats) { { processed: 5, skipped_other: 2 } }
    let(:ai_stats) { { processed: 2, failed: 0 } }
    let(:non_other_ai_stats) { { processed: 3, failed: 0 } }

    before do
      TradeTariffRequest.time_machine_now = Time.current
      TradeTariffBackend.redis.set(GenerateSelfTextWorker::REDIS_KEY, '2')

      allow(GenerateSelfText::MechanicalBuilder).to receive(:call).and_return(mechanical_stats)
      allow(GenerateSelfText::OtherSelfTextBuilder).to receive(:call).and_return(ai_stats)
      allow(GenerateSelfText::NonOtherSelfTextBuilder).to receive(:call).and_return(non_other_ai_stats)
      allow(SelfTextGenerator::Instrumentation).to receive(:chapter_started)
      allow(SelfTextGenerator::Instrumentation).to receive(:chapter_completed).and_call_original
      allow(SelfTextGenerator::Instrumentation).to receive(:generation_completed)
      allow(GenerateSelfTextReindexWorker).to receive(:perform_async)
    end

    it 'calls OtherSelfTextBuilder, NonOtherSelfTextBuilder, then MechanicalBuilder' do
      described_class.new.perform(chapter_sid)

      expect(GenerateSelfText::OtherSelfTextBuilder).to have_received(:call).with(chapter).ordered
      expect(GenerateSelfText::NonOtherSelfTextBuilder).to have_received(:call).with(chapter).ordered
      expect(GenerateSelfText::MechanicalBuilder).to have_received(:call).with(chapter).ordered
    end

    it 'instruments chapter_started' do
      described_class.new.perform(chapter_sid)

      expect(SelfTextGenerator::Instrumentation).to have_received(:chapter_started).with(
        chapter_sid:,
        chapter_code: chapter.short_code,
      )
    end

    it 'instruments chapter_completed with stats' do
      described_class.new.perform(chapter_sid)

      expect(SelfTextGenerator::Instrumentation).to have_received(:chapter_completed).with(
        chapter_sid:,
        chapter_code: chapter.short_code,
      )
    end

    it 'decrements the Redis counter' do
      described_class.new.perform(chapter_sid)

      expect(TradeTariffBackend.redis.get(GenerateSelfTextWorker::REDIS_KEY).to_i).to eq(1)
    end

    context 'when counter reaches zero' do
      before do
        TradeTariffBackend.redis.set(GenerateSelfTextWorker::REDIS_KEY, '1')
      end

      it 'triggers reindex' do
        described_class.new.perform(chapter_sid)

        expect(GenerateSelfTextReindexWorker).to have_received(:perform_async)
      end

      it 'instruments generation_completed' do
        described_class.new.perform(chapter_sid)

        expect(SelfTextGenerator::Instrumentation).to have_received(:generation_completed)
      end
    end

    context 'when counter is above zero' do
      before do
        TradeTariffBackend.redis.set(GenerateSelfTextWorker::REDIS_KEY, '3')
      end

      it 'does not trigger reindex' do
        described_class.new.perform(chapter_sid)

        expect(GenerateSelfTextReindexWorker).not_to have_received(:perform_async)
      end

      it 'does not instrument generation_completed' do
        described_class.new.perform(chapter_sid)

        expect(SelfTextGenerator::Instrumentation).not_to have_received(:generation_completed)
      end
    end

    context 'when chapter is not found' do
      it 'returns early without processing' do
        described_class.new.perform(-999)

        expect(GenerateSelfText::MechanicalBuilder).not_to have_received(:call)
        expect(GenerateSelfText::OtherSelfTextBuilder).not_to have_received(:call)
        expect(GenerateSelfText::NonOtherSelfTextBuilder).not_to have_received(:call)
      end
    end

    context 'when an error occurs' do
      before do
        allow(GenerateSelfText::MechanicalBuilder).to receive(:call).and_raise(StandardError, 'DB timeout')
        allow(SelfTextGenerator::Instrumentation).to receive(:chapter_failed)
      end

      it 'instruments chapter_failed and re-raises' do
        expect { described_class.new.perform(chapter_sid) }.to raise_error(StandardError, 'DB timeout')

        expect(SelfTextGenerator::Instrumentation).to have_received(:chapter_failed).with(
          chapter_sid:,
          chapter_code: chapter.short_code,
          error: an_instance_of(StandardError),
        )
      end

      it 'does not decrement the Redis counter' do
        expect { described_class.new.perform(chapter_sid) }.to raise_error(StandardError)

        expect(TradeTariffBackend.redis.get(GenerateSelfTextWorker::REDIS_KEY).to_i).to eq(2)
      end
    end
  end

  describe 'sidekiq options' do
    it 'uses the within_1_day queue' do
      expect(described_class.sidekiq_options['queue']).to eq(:within_1_day)
    end

    it 'retries twice' do
      expect(described_class.sidekiq_options['retry']).to eq(2)
    end
  end
end
