require 'rails_helper'

RSpec.describe EvaluationExperiment do
  it 'requires a name' do
    experiment = build(:evaluation_experiment, name: nil)
    expect(experiment.valid?).to be false
    expect(experiment.errors[:name]).to be_present
  end

  it 'enforces name uniqueness' do
    create(:evaluation_experiment, name: 'baseline-gpt4o')
    dup = build(:evaluation_experiment, name: 'baseline-gpt4o')
    expect(dup.valid?).to be false
    expect(dup.errors[:name]).to be_present
  end

  it 'has no gold query set unless one is chosen' do
    expect(create(:evaluation_experiment).evaluation_gold_query_set).to be_nil
  end

  it 'can point at a gold query set' do
    gold_query_set = create(:evaluation_gold_query_set)
    experiment = create(:evaluation_experiment, gold_query_set_id: gold_query_set.id)

    expect(experiment.evaluation_gold_query_set).to eq(gold_query_set)
  end

  it 'refuses a gold query set that does not exist' do
    experiment = build(:evaluation_experiment, gold_query_set_id: 999_999)

    expect(experiment.valid?).to be false
    expect(experiment.errors[:gold_query_set_id]).to eq(['does not exist'])
  end

  it 'refuses to change to a gold query set that does not exist, even after a valid one was loaded' do
    experiment = create(:evaluation_experiment, gold_query_set_id: create(:evaluation_gold_query_set).id)
    experiment.evaluation_gold_query_set

    experiment.gold_query_set_id = 999_999

    expect(experiment.valid?).to be false
  end

  it 'defaults enabled to true' do
    experiment = create(:evaluation_experiment, name: 'defaults-test')
    expect(experiment.enabled).to be true
  end

  it 'defaults configuration_overrides and default_scope to empty hashes' do
    experiment = create(:evaluation_experiment, name: 'defaults-test-2')
    expect(experiment.configuration_overrides).to eq({})
    expect(experiment.default_scope).to eq({})
  end
end
