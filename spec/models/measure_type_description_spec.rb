RSpec.describe MeasureTypeDescription do
  describe '#to_s' do
    subject(:measure_type_description) { build :measure_type_description, description: 'Third country duty' }

    it { expect(measure_type_description.to_s).to eq('Third country duty') }
  end

  describe '#measure_type' do
    subject { measure_type_description.reload.measure_type }

    let(:measure_type) { create :measure_type }
    let(:measure_type_description) { create :measure_type_description, measure_type_id: measure_type.measure_type_id }

    it { is_expected.to eq(measure_type) }
  end
end
