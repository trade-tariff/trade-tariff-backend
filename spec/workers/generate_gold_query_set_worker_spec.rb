RSpec.describe GenerateGoldQuerySetWorker, type: :worker do
  let(:gold_query_set) { create(:evaluation_gold_query_set, planned_count: 2) }
  let(:items) { [%w[atar 600000001], %w[synthetic_atar 42]] }

  before { allow(GenerateGoldQueryItemWorker).to receive(:perform_bulk) }

  describe '#perform' do
    it 'queues one item job per source item, carrying the set id and the item' do
      described_class.new.perform(gold_query_set.id, items)

      expect(GenerateGoldQueryItemWorker).to have_received(:perform_bulk).with(
        [[gold_query_set.id, 'atar', '600000001'], [gold_query_set.id, 'synthetic_atar', '42']],
      )
    end

    it 'queues nothing when the set has been deleted' do
      described_class.new.perform(999_999, items)

      expect(GenerateGoldQueryItemWorker).not_to have_received(:perform_bulk)
    end

    it 'queues nothing on the XI service' do
      allow(TradeTariffBackend).to receive(:uk?).and_return(false)

      described_class.new.perform(gold_query_set.id, items)

      expect(GenerateGoldQueryItemWorker).not_to have_received(:perform_bulk)
    end
  end

  describe 'Sidekiq options' do
    it 'runs on the within_1_day queue, like the other LLM fan-outs, and is never retried' do
      expect(described_class.get_sidekiq_options).to include('queue' => :within_1_day, 'retry' => 0)
    end
  end

  describe 'when Sidekiq gives up (retry: 0 means this fires on the very first failure)' do
    it 'marks the set as failed instead of leaving it stuck in generating forever' do
      job = { 'args' => [gold_query_set.id, items] }

      described_class.sidekiq_retries_exhausted_block.call(job, StandardError.new('redis is down'))

      expect(gold_query_set.reload).to have_attributes(status: 'failed', failed_count: gold_query_set.planned_count)
      expect(gold_query_set.failures.first['error']).to include('redis is down')
    end

    it 'does nothing when the set has already been deleted' do
      job = { 'args' => [999_999, items] }

      expect { described_class.sidekiq_retries_exhausted_block.call(job, StandardError.new('redis is down')) }.not_to raise_error
    end
  end
end
