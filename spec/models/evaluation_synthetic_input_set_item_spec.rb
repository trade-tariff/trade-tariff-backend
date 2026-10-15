require 'rails_helper'

RSpec.describe EvaluationSyntheticInputSetItem do
  it 'requires a set, a synthetic ATaR, a query and an expected code' do
    item = build(
      :evaluation_synthetic_input_set_item,
      evaluation_synthetic_input_set: nil, synthetic_atar_id: nil, query: nil, expected_code: nil,
    )

    expect(item.valid?).to be false
    expect(item.errors[:set_id]).to be_present
    expect(item.errors[:synthetic_atar_id]).to be_present
    expect(item.errors[:query]).to be_present
    expect(item.errors[:expected_code]).to be_present
  end

  it 'refuses to delete a synthetic ATaR that a set item still references' do
    synthetic_atar = create(:tariff_knowledge_synthetic_atar)
    create(:evaluation_synthetic_input_set_item, synthetic_atar_id: synthetic_atar.id)

    expect { synthetic_atar.destroy }.to raise_error(Sequel::ForeignKeyConstraintViolation)
  end

  it 'is deleted when its set is deleted' do
    item = create(:evaluation_synthetic_input_set_item)
    set = item.evaluation_synthetic_input_set

    expect { set.destroy }.to change(described_class, :count).by(-1)
  end
end
