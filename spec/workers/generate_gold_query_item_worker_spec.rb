RSpec.describe GenerateGoldQueryItemWorker, type: :worker do
  let(:gold_query_set) { create(:evaluation_gold_query_set, planned_count: 2, created_by: 'user-123') }
  let(:ruling) { create(:tariff_knowledge_public_atar_ruling, ref: '600014988', description: 'Bed linen woven from cotton fabric.') }
  let(:tiers) { { 'generic' => 'bed linen', 'ordinary' => 'cotton bed sheets', 'specific' => 'printed cotton bed linen set' } }

  describe '#perform' do
    context 'when the generator produces gold queries' do
      before { allow(Evaluation::GoldQueryGenerator).to receive(:call).and_return(tiers) }

      it 'generates for the source item and counts it as generated' do
        described_class.new.perform(gold_query_set.id, 'atar', ruling.ref)

        expect(Evaluation::GoldQueryGenerator).to have_received(:call)
          .with(have_attributes(source_type: 'atar', source_id: '600014988'), set: gold_query_set)
        expect(gold_query_set.reload).to have_attributes(generated_count: 1, failed_count: 0, status: 'generating')
      end

      it 'can generate for a synthetic ATaR, finding it from its id as a string' do
        synthetic_atar = create(:tariff_knowledge_synthetic_atar)

        described_class.new.perform(gold_query_set.id, 'synthetic_atar', synthetic_atar.id.to_s)

        expect(Evaluation::GoldQueryGenerator).to have_received(:call)
          .with(have_attributes(source_type: 'synthetic_atar', real_user_search: synthetic_atar.real_user_search), set: gold_query_set)
      end
    end

    context 'when the generator finds no acceptable phrases' do
      before { allow(Evaluation::GoldQueryGenerator).to receive(:call).and_return(nil) }

      it 'counts the item as failed straight away, with the reason' do
        described_class.new.perform(gold_query_set.id, 'atar', ruling.ref)

        expect(gold_query_set.reload).to have_attributes(generated_count: 0, failed_count: 1)
        expect(gold_query_set.failures.to_a.map(&:to_h)).to eq(
          [{ 'source_type' => 'atar', 'source_id' => '600014988', 'error' => 'the model did not return acceptable phrases after 3 attempts' }],
        )
      end
    end

    context 'when the source item no longer exists' do
      before { allow(Evaluation::GoldQueryGenerator).to receive(:call) }

      it 'counts the item as failed without calling the generator' do
        described_class.new.perform(gold_query_set.id, 'atar', '000000000')

        expect(Evaluation::GoldQueryGenerator).not_to have_received(:call)
        expect(gold_query_set.reload.failed_count).to eq(1)
        expect(gold_query_set.failures.first['error']).to eq('the source item no longer exists')
      end
    end

    context 'when the set has been deleted' do
      before { allow(Evaluation::GoldQueryGenerator).to receive(:call) }

      it 'does nothing' do
        expect { described_class.new.perform(999_999, 'atar', ruling.ref) }.not_to raise_error

        expect(Evaluation::GoldQueryGenerator).not_to have_received(:call)
      end
    end

    context 'when the service is XI' do
      before do
        allow(TradeTariffBackend).to receive(:uk?).and_return(false)
        allow(Evaluation::GoldQueryGenerator).to receive(:call)
      end

      it 'does nothing' do
        described_class.new.perform(gold_query_set.id, 'atar', ruling.ref)

        expect(Evaluation::GoldQueryGenerator).not_to have_received(:call)
        expect(gold_query_set.reload.generated_count).to eq(0)
      end
    end

    context 'with the real generator and a fake AI client' do
      let(:ai_client) { instance_double(OpenaiClient, call: tiers) }

      before { allow(TradeTariffBackend).to receive(:ai_client).and_return(ai_client) }

      it 'saves three gold queries in the set, with history, and finishes a one item set as ready' do
        one_item_set = create(:evaluation_gold_query_set, planned_count: 1, created_by: 'user-123')

        described_class.new.perform(one_item_set.id, 'atar', ruling.ref)

        rows = EvaluationGoldQuery.where(set_id: one_item_set.id).order(:persona).all
        expect(rows.map(&:persona)).to eq(%w[emu_generic emu_ordinary emu_specific])
        expect(rows.flat_map { |row| row.versions.map(&:whodunnit) }.uniq).to eq(%w[user-123])
        expect(one_item_set.reload).to have_attributes(generated_count: 1, status: 'ready')
      end
    end

    it 'finishes a two item set as partly_failed when one item generates and one does not' do
      allow(Evaluation::GoldQueryGenerator).to receive(:call).and_return(tiers, nil)

      described_class.new.perform(gold_query_set.id, 'atar', ruling.ref)
      described_class.new.perform(gold_query_set.id, 'atar', ruling.ref)

      expect(gold_query_set.reload).to have_attributes(generated_count: 1, failed_count: 1, status: 'partly_failed')
    end
  end

  describe 'when Sidekiq gives up after its retries' do
    it 'counts the item as failed, with the exception, so the set can still finish' do
      job = { 'args' => [gold_query_set.id, 'atar', '600014988'] }

      described_class.sidekiq_retries_exhausted_block.call(job, StandardError.new('connection lost'))

      expect(gold_query_set.reload.failed_count).to eq(1)
      expect(gold_query_set.failures.first).to include('source_id' => '600014988', 'error' => 'StandardError: connection lost')
    end

    it 'keeps the stored error short' do
      job = { 'args' => [gold_query_set.id, 'atar', '600014988'] }

      described_class.sidekiq_retries_exhausted_block.call(job, StandardError.new('x' * 2_000))

      expect(gold_query_set.reload.failures.first['error'].length).to be <= 500
    end
  end

  describe 'Sidekiq options' do
    it 'runs on the within_1_day queue, like the other LLM fan-outs' do
      expect(described_class.get_sidekiq_options).to include('queue' => :within_1_day, 'retry' => 3)
    end
  end
end
