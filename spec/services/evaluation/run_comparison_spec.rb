RSpec.describe Evaluation::RunComparison do
  let(:openai_run) { create(:evaluation_run, question_model: 'gpt-5.6-terra') }
  let(:bedrock_run) { create(:evaluation_run, question_model: 'bedrock/gpt-5.6-terra') }

  before do
    # OpenAI: 4 results, one errored. Latencies 1, 2, 3 (+ 9 errored); cost 0.01 each.
    [[1, true, true], [2, false, true], [3, false, false]].each do |latency, top1, top5|
      create(:evaluation_result, evaluation_run: openai_run, latency_seconds: latency, gold_in_top1: top1, gold_in_top5: top5, cost_usd: 0.01, provider_calls: 2)
    end
    create(:evaluation_result, evaluation_run: openai_run, latency_seconds: 9, error: 'timeout', cost_usd: 0.01, provider_calls: 1)

    create(:evaluation_result, evaluation_run: bedrock_run, latency_seconds: 4, gold_in_top1: true, gold_in_top5: true, cost_usd: 0.02, provider_calls: 3)
  end

  describe '.call' do
    subject(:rows) { described_class.call([bedrock_run.id, openai_run.id]) }

    it 'returns one row per run, in the order given' do
      expect(rows.map(&:run_id)).to eq([bedrock_run.id, openai_run.id])
    end

    it 'reports quality and latency without errored results' do
      expect(rows.last).to have_attributes(
        question_model: 'gpt-5.6-terra',
        provider: 'OpenAI',
        results: 4,
        errors: 1,
        top1_pct: 33.3,
        top5_pct: 66.7,
        p50_latency_seconds: 2.0,
        p95_latency_seconds: 2.9,
      )
    end

    it 'reports cost per 1,000 searches including errored results' do
      expect(rows.last).to have_attributes(mean_provider_calls: 1.75, cost_per_1000_usd: 10.0)
    end

    it 'adds the gb regional uplift to OpenAI runs of post-March-2026 models' do
      expect(rows.last.cost_per_1000_with_gb_uplift_usd).to eq(11.0)
    end

    it 'does not add the gb uplift to Bedrock runs' do
      expect(rows.first).to have_attributes(provider: 'Bedrock', cost_per_1000_usd: 20.0, cost_per_1000_with_gb_uplift_usd: 20.0)
    end

    it 'raises for an unknown run id' do
      expect { described_class.call([openai_run.id, 0]) }.to raise_error(ArgumentError, /0/)
    end
  end
end
