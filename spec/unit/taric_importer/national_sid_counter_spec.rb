# frozen_string_literal: true

RSpec.describe TaricImporter::NationalSidCounter do
  subject(:counter) { described_class.new }

  before { MeasureCondition.unrestrict_primary_key }

  context 'without existing national records' do
    it 'seeds from the model and decrements on each call' do
      expect(counter.next_for(MeasureCondition)).to eq(-1)
      expect(counter.next_for(MeasureCondition)).to eq(-2)
      expect(counter.next_for(MeasureCondition)).to eq(-3)
    end
  end

  context 'with an existing national record' do
    before { create(:measure_condition, measure_condition_sid: -5) }

    it 'seeds below the current minimum and decrements on each call' do
      expect(counter.next_for(MeasureCondition)).to eq(-6)
      expect(counter.next_for(MeasureCondition)).to eq(-7)
    end
  end

  it 'only reads the model once per class, regardless of how many values are handed out' do
    expect(MeasureCondition).to receive(:next_national_sid).once.and_call_original

    counter.next_for(MeasureCondition)
    counter.next_for(MeasureCondition)
  end
end
