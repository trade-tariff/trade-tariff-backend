# spec/models/evaluation_gold_query_spec.rb
require 'rails_helper'

RSpec.describe EvaluationGoldQuery do
  it 'requires a set, source_type, source_id, persona, query, expected_code and oracle_text' do
    record = build(
      :evaluation_gold_query,
      evaluation_gold_query_set: nil, source_type: nil, source_id: nil, persona: nil, query: nil, expected_code: nil, oracle_text: nil,
    )

    expect(record.valid?).to be false
    expect(record.errors[:set_id]).to be_present
    expect(record.errors[:source_type]).to be_present
    expect(record.errors[:source_id]).to be_present
    expect(record.errors[:persona]).to be_present
    expect(record.errors[:query]).to be_present
    expect(record.errors[:expected_code]).to be_present
    expect(record.errors[:oracle_text]).to be_present
  end

  it 'accepts the two known source types and refuses any other' do
    expect(build(:evaluation_gold_query, source_type: 'atar')).to be_valid
    expect(build(:evaluation_gold_query, source_type: 'synthetic_atar')).to be_valid
    expect(build(:evaluation_gold_query, source_type: 'made_up')).not_to be_valid
  end

  it 'creates a valid record with all fields set' do
    record = create(
      :evaluation_gold_query,
      source_type: 'atar',
      source_id: '600000001',
      persona: 'emu_generic',
      query: 'cotton bed linen',
      expected_code: '6302100000',
      expected_description: 'Bed linen of cotton',
      notes: 'ported emulator',
      generator: 'gpt-5-mini',
    )

    expect(record.id).to be_present
    expect(record.expected_description).to eq('Bed linen of cotton')
  end

  it 'defaults active to true' do
    record = create(:evaluation_gold_query)

    expect(record.active).to be true
  end

  it 'reports expected_code_digits as the literal length of expected_code, preserving native ATaR granularity' do
    full_leaf = build(:evaluation_gold_query, expected_code: '6302100000')
    heading_level = build(:evaluation_gold_query, expected_code: '63021000')
    chapter_level = build(:evaluation_gold_query, expected_code: '630210')

    expect(full_leaf.expected_code_digits).to eq(10)
    expect(heading_level.expected_code_digits).to eq(8)
    expect(chapter_level.expected_code_digits).to eq(6)
  end

  it 'enforces uniqueness on (set_id, source_type, source_id, persona) at the database level' do
    existing = create(:evaluation_gold_query, source_type: 'atar', source_id: '600000001', persona: 'emu_generic')

    expect {
      described_class.db[:evaluation_gold_queries].insert(
        set_id: existing.set_id, source_type: 'atar', source_id: '600000001', persona: 'emu_generic',
        query: 'x', expected_code: '6302100000', oracle_text: 'x'
      )
    }.to raise_error(Sequel::UniqueConstraintViolation)
  end

  it 'lets the same source item and persona appear in two different sets' do
    create(:evaluation_gold_query, source_type: 'atar', source_id: '600000001', persona: 'emu_generic')

    expect { create(:evaluation_gold_query, source_type: 'atar', source_id: '600000001', persona: 'emu_generic') }
      .not_to raise_error
  end

  it 'belongs to its set' do
    gold_query_set = create(:evaluation_gold_query_set)
    record = create(:evaluation_gold_query, evaluation_gold_query_set: gold_query_set)

    expect(record.evaluation_gold_query_set).to eq(gold_query_set)
  end

  describe 'versioning' do
    it 'records history when an operator edits a row' do
      record = create(:evaluation_gold_query, query: 'original query')

      record.update(query: 'edited query')

      expect(record.versions.map(&:event)).to eq(%w[create update])
      expect(record.versions.last.object.to_h).to include('query' => 'edited query')
    end
  end
end
