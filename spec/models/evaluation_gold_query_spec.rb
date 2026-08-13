# spec/models/evaluation_gold_query_spec.rb
require 'rails_helper'

RSpec.describe EvaluationGoldQuery do
  it 'requires source_type, source_id, persona, query and expected_code' do
    record = build(
      :evaluation_gold_query,
      source_type: nil, source_id: nil, persona: nil, query: nil, expected_code: nil,
    )

    expect(record.valid?).to be false
    expect(record.errors[:source_type]).to be_present
    expect(record.errors[:source_id]).to be_present
    expect(record.errors[:persona]).to be_present
    expect(record.errors[:query]).to be_present
    expect(record.errors[:expected_code]).to be_present
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

  it 'enforces uniqueness on (source_type, source_id, persona) at the database level' do
    create(:evaluation_gold_query, source_type: 'atar', source_id: '600000001', persona: 'emu_generic')

    expect {
      described_class.db[:evaluation_gold_queries].insert(
        source_type: 'atar', source_id: '600000001', persona: 'emu_generic',
        query: 'x', expected_code: '6302100000'
      )
    }.to raise_error(Sequel::UniqueConstraintViolation)
  end
end
