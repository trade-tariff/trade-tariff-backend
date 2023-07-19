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

  describe '#condition_duty_amount' do
    subject(:condition_duty_amount) { described_class.new(measure, measure_condition).condition_duty_amount }

    shared_examples 'a measure condition presented condition duty amount' do |expected_condition_duty_amount|
      it { is_expected.to eq(expected_condition_duty_amount) }
    end

    it_behaves_like 'a measure condition presented condition duty amount', 1.0 do
      let(:measure) { create(:measure, :excise) }
      let(:measure_condition) { create(:measure_condition, measure:, condition_measurement_unit_code: 'ASV', condition_duty_amount: 0.01) }
    end

    it_behaves_like 'a measure condition presented condition duty amount', 0.01 do
      let(:measure) { create(:measure) }
      let(:measure_condition) { create(:measure_condition, measure:, condition_duty_amount: 0.01) }
    end

    it_behaves_like 'a measure condition presented condition duty amount', nil do
      let(:measure) { create(:measure) }
      let(:measure_condition) do
        create(
          :measure_condition,
          measure:,
          condition_duty_amount: nil,
        )
      end
    end
  end

  describe '#requirement_duty_expression' do
    subject(:requirement_duty_expression) do
      described_class.new(measure, measure_condition).requirement_duty_expression
    end

    shared_examples 'a presented requirement duty expression' do |expected_duty_amount|
      it { is_expected.to match(expected_duty_amount) }
    end

    it_behaves_like 'a presented requirement duty expression', /^<span>1.00<\/span>.*$/ do
      let(:measure) { create(:measure, :excise) }
      let(:measure_condition) do
        create(
          :measure_condition,
          measure:,
          condition_measurement_unit_code: 'ASV',
          condition_duty_amount: 0.01,
        )
      end
    end

    it_behaves_like 'a presented requirement duty expression', /^<span>0.01<\/span>.*$/ do
      let(:measure) { create(:measure) }
      let(:measure_condition) do
        create(
          :measure_condition,
          measure:,
          condition_duty_amount: 0.01,
        )
      end
    end
  end
end
