require 'rails_helper'

RSpec.describe EvaluationResult do
  let(:experiment) { create(:evaluation_experiment) }
  let(:run) { create(:evaluation_run, evaluation_experiment: experiment) }

  it 'belongs to a run' do
    result = create(
      :evaluation_result,
      evaluation_run: run, source_type: 'atar', source_id: 'A123',
      persona: 'original', expected_code: '8471300000'
    )
    expect(result.evaluation_run).to eq(run)
  end

  it 'enforces uniqueness on (run_id, source_id, persona)' do
    create(
      :evaluation_result,
      evaluation_run: run, source_type: 'atar', source_id: 'A123',
      persona: 'original', expected_code: '8471300000'
    )

    expect {
      described_class.db[:evaluation_results].insert(
        run_id: run.id, source_type: 'atar', source_id: 'A123',
        persona: 'original', expected_code: '8471300000'
      )
    }.to raise_error(Sequel::UniqueConstraintViolation)
  end

  it 'is deleted when its run is deleted' do
    result = create(
      :evaluation_result,
      evaluation_run: run, source_type: 'atar', source_id: 'A123',
      persona: 'original', expected_code: '8471300000'
    )
    run.destroy
    expect(described_class[result.id]).to be_nil
  end

  it 'defaults gold_in_top1/gold_in_top5 to false and trace to an empty hash' do
    result = create(
      :evaluation_result,
      evaluation_run: run, source_type: 'atar', source_id: 'A124',
      persona: 'original', expected_code: '8471300000'
    )
    expect(result.gold_in_top1).to be false
    expect(result.gold_in_top5).to be false
    expect(result.trace).to eq({})
  end

  describe 'provider_calls' do
    it 'defaults to zero' do
      result = create(:evaluation_result, evaluation_run: run)
      expect(result.provider_calls).to eq(0)
    end

    it 'stores an explicit value' do
      result = create(:evaluation_result, evaluation_run: run, provider_calls: 3)
      expect(result.provider_calls).to eq(3)
    end
  end
end
