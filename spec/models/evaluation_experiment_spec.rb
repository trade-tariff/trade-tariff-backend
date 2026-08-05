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
