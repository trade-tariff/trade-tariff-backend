require 'rails_helper'

RSpec.describe EvaluationResult do
  describe '.ingest!' do
    let(:experiment) { create(:evaluation_experiment) }
    let(:run) { create(:evaluation_run, evaluation_experiment: experiment) }

    it 'creates a new result on first ingestion' do
      result = described_class.ingest!(
        run:, source_type: 'atar', source_id: 'A200', persona: 'original',
        attrs: { expected_code: '8471300000', final_code: '8471300000', gold_in_top1: true }
      )
      expect(result.final_code).to eq('8471300000')
      expect(described_class.where(run_id: run.id).count).to eq(1)
    end

    it 'overwrites rather than duplicates on a retried ingestion of the same source/persona' do
      described_class.ingest!(
        run:, source_type: 'atar', source_id: 'A200', persona: 'original',
        attrs: { expected_code: '8471300000', final_code: nil, error: 'timeout' }
      )
      described_class.ingest!(
        run:, source_type: 'atar', source_id: 'A200', persona: 'original',
        attrs: { expected_code: '8471300000', final_code: '8471300000', error: nil }
      )

      expect(described_class.where(run_id: run.id).count).to eq(1)
      result = described_class.first(run_id: run.id, source_id: 'A200', persona: 'original')
      expect(result.final_code).to eq('8471300000')
      expect(result.error).to be_nil
    end

    it 'treats a different persona for the same source_id as a distinct result' do
      described_class.ingest!(
        run:, source_type: 'atar', source_id: 'A200', persona: 'original',
        attrs: { expected_code: '8471300000' }
      )
      described_class.ingest!(
        run:, source_type: 'atar', source_id: 'A200', persona: 'naive_vague',
        attrs: { expected_code: '8471300000' }
      )
      expect(described_class.where(run_id: run.id).count).to eq(2)
    end

    it 'treats the same source_id/persona under a different run as a distinct result' do
      other_run = create(:evaluation_run, evaluation_experiment: experiment)
      described_class.ingest!(run:, source_type: 'atar', source_id: 'A200', persona: 'original', attrs: { expected_code: '8471300000' })
      described_class.ingest!(run: other_run, source_type: 'atar', source_id: 'A200', persona: 'original', attrs: { expected_code: '8471300000' })

      expect(described_class.where(run_id: run.id).count).to eq(1)
      expect(described_class.where(run_id: other_run.id).count).to eq(1)
    end

    it 'persists a trace Hash as jsonb and reads it back correctly from the database' do
      trace = { 'query' => 'foo', 'candidates' => [1, 2] }

      described_class.ingest!(
        run:, source_type: 'atar', source_id: 'A200', persona: 'original',
        attrs: { expected_code: '8471300000', trace: }
      )

      reloaded = described_class.first(run_id: run.id, source_id: 'A200', persona: 'original')
      expect(reloaded.trace).to eq(trace)
    end

    it 'overwrites the stored trace on a retried ingestion with a different trace' do
      described_class.ingest!(
        run:, source_type: 'atar', source_id: 'A200', persona: 'original',
        attrs: { expected_code: '8471300000', trace: { 'query' => 'first' } }
      )
      described_class.ingest!(
        run:, source_type: 'atar', source_id: 'A200', persona: 'original',
        attrs: { expected_code: '8471300000', trace: { 'query' => 'second', 'candidates' => [3, 4] } }
      )

      reloaded = described_class.first(run_id: run.id, source_id: 'A200', persona: 'original')
      expect(reloaded.trace).to eq({ 'query' => 'second', 'candidates' => [3, 4] })
    end
  end
end
