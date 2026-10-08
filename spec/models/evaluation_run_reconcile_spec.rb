require 'rails_helper'

RSpec.describe EvaluationRun do
  describe '#reconcile_aggregates!' do
    let(:experiment) { create(:evaluation_experiment) }
    let(:run) { create(:evaluation_run, evaluation_experiment: experiment, status: 'running') }

    it 'counts all results belonging to the run' do
      EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A1', persona: 'original', attrs: { expected_code: '1' })
      EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A2', persona: 'original', attrs: { expected_code: '2' })

      run.reconcile_aggregates!
      expect(run.result_count).to eq(2)
    end

    it 'counts only results with a non-nil error' do
      EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A1', persona: 'original', attrs: { expected_code: '1', error: 'timeout' })
      EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A2', persona: 'original', attrs: { expected_code: '2' })

      run.reconcile_aggregates!
      expect(run.error_count).to eq(1)
    end

    it 'sums cost and latency across results, treating nils as zero' do
      EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A1', persona: 'original', attrs: { expected_code: '1', cost_usd: 0.01, latency_seconds: 2.5 })
      EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A2', persona: 'original', attrs: { expected_code: '2', cost_usd: nil, latency_seconds: 1.5 })

      run.reconcile_aggregates!
      expect(run.total_cost_usd.to_f).to eq(0.01)
      expect(run.total_latency_seconds.to_f).to eq(4.0)
    end

    it 'sums provider_calls across results, treating nils as zero' do
      EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A1', persona: 'original', attrs: { expected_code: '1', provider_calls: 2 })
      EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A2', persona: 'original', attrs: { expected_code: '2', provider_calls: 1 })

      run.reconcile_aggregates!
      expect(run.total_provider_calls).to eq(3)
    end

    it 'resets aggregates to zero when the run has no results' do
      run.reconcile_aggregates!
      expect(run.result_count).to eq(0)
      expect(run.error_count).to eq(0)
      expect(run.total_cost_usd.to_f).to eq(0.0)
      expect(run.total_latency_seconds.to_f).to eq(0.0)
      expect(run.total_provider_calls).to eq(0)
    end

    it 'persists the reconciled values' do
      EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A1', persona: 'original', attrs: { expected_code: '1' })
      run.reconcile_aggregates!
      expect(described_class[run.id].result_count).to eq(1)
    end

    it 'counts how many results had the gold code in the top 1 and top 5' do
      EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A1', persona: 'original', attrs: { expected_code: '1', gold_in_top1: true, gold_in_top5: true })
      EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A2', persona: 'original', attrs: { expected_code: '2', gold_in_top1: false, gold_in_top5: true })
      EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A3', persona: 'original', attrs: { expected_code: '3', gold_in_top1: false, gold_in_top5: false })

      run.reconcile_aggregates!
      expect(run.gold_in_top1_count).to eq(1)
      expect(run.gold_in_top5_count).to eq(2)
    end

    it 'records which result was the most and least expensive, ignoring results with no recorded cost' do
      cheap = EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A1', persona: 'original', attrs: { expected_code: '1', cost_usd: 0.001 })
      expensive = EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A2', persona: 'original', attrs: { expected_code: '2', cost_usd: 0.05 })
      EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A3', persona: 'original', attrs: { expected_code: '3', cost_usd: nil })

      run.reconcile_aggregates!
      expect(run.max_cost_result_id).to eq(expensive.id)
      expect(run.min_cost_result_id).to eq(cheap.id)
    end

    it 'records which result was the slowest and fastest, ignoring results with no recorded latency' do
      fast = EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A1', persona: 'original', attrs: { expected_code: '1', latency_seconds: 0.8 })
      slow = EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A2', persona: 'original', attrs: { expected_code: '2', latency_seconds: 12.4 })
      EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A3', persona: 'original', attrs: { expected_code: '3', latency_seconds: nil })

      run.reconcile_aggregates!
      expect(run.max_latency_result_id).to eq(slow.id)
      expect(run.min_latency_result_id).to eq(fast.id)
    end

    it 'leaves the outlier pointers nil when the run has no results' do
      run.reconcile_aggregates!

      expect(run.gold_in_top1_count).to eq(0)
      expect(run.gold_in_top5_count).to eq(0)
      expect(run.max_cost_result_id).to be_nil
      expect(run.min_cost_result_id).to be_nil
      expect(run.max_latency_result_id).to be_nil
      expect(run.min_latency_result_id).to be_nil
    end

    it 'counts results priced against a model missing from the pricing table, so totals can be flagged as incomplete' do
      EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A1', persona: 'original', attrs: { expected_code: '1', cost_usd: 0.01, pricing_known: true })
      EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A2', persona: 'original', attrs: { expected_code: '2', cost_usd: 0, pricing_known: false })

      run.reconcile_aggregates!
      expect(run.unpriced_result_count).to eq(1)
    end

    it 'breaks accuracy, cost and latency down by persona, so one persona can be compared against another' do
      EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A1', persona: 'emu_generic', attrs: { expected_code: '1', gold_in_top1: true, gold_in_top5: true, cost_usd: 0.01, latency_seconds: 2.0 })
      EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A2', persona: 'emu_generic', attrs: { expected_code: '2', gold_in_top1: false, gold_in_top5: true, cost_usd: 0.02, latency_seconds: 3.0 })
      EvaluationResult.ingest!(run:, source_type: 'atar', source_id: 'A3', persona: 'emu_specific', attrs: { expected_code: '3', gold_in_top1: true, gold_in_top5: true, cost_usd: 0.05, latency_seconds: 1.0 })

      run.reconcile_aggregates!

      expect(run.persona_breakdown).to eq(
        'emu_generic' => { 'result_count' => 2, 'gold_in_top1_count' => 1, 'gold_in_top5_count' => 2, 'total_cost_usd' => 0.03, 'total_latency_seconds' => 5.0 },
        'emu_specific' => { 'result_count' => 1, 'gold_in_top1_count' => 1, 'gold_in_top5_count' => 1, 'total_cost_usd' => 0.05, 'total_latency_seconds' => 1.0 },
      )
    end

    it 'is an empty breakdown, not an error, when the run has no results' do
      run.reconcile_aggregates!

      expect(run.persona_breakdown).to eq({})
    end
  end
end
