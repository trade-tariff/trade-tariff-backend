RSpec.describe Api::V2::Measures::MeasureConditionPresenter do
  describe '#measure_condition_components' do
    subject(:measure_condition_components) { described_class.new(measure, measure_condition).measure_condition_components }

    let(:measure) { create(:measure, :with_measure_conditions) }
    let(:measure_condition) { measure.measure_conditions.first }

    it { is_expected.to all(be_a(Api::V2::Measures::MeasureConditionComponentPresenter)) }
  end

  describe '.wrap' do
    subject(:wrapped_measure_conditions) { described_class.wrap(measure, measure_conditions) }

    let(:measure) { create(:measure, :with_measure_conditions) }
    let(:measure_conditions) { measure.measure_conditions }

    it { is_expected.to all(be_a(described_class)) }
  end
end
