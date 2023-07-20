RSpec.describe Api::V2::Measures::MeasureConditionPresenter do
  subject(:presenter) { described_class.new(measure_condition, measure) }

  describe '#measure_condition_components' do
    let(:measure) { create(:measure, :with_measure_conditions) }
    let(:measure_condition) { measure.measure_conditions.first }

    it { expect(presenter.measure_condition_components).to all(be_a(Api::V2::Measures::MeasureConditionComponentPresenter)) }
  end

  describe '#condition_duty_amount' do
    shared_examples 'a measure condition presented condition duty amount' do |expected_condition_duty_amount|
      it { expect(presenter.condition_duty_amount).to eq(expected_condition_duty_amount) }
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

  describe '#duty_expression' do
    shared_examples 'a measure condition presented duty expression' do |expected_duty_expression|
      it { expect(presenter.duty_expression).to match(expected_duty_expression) }
    end

    it_behaves_like 'a measure condition presented duty expression', /^<span>5.00<\/span>.*<span>100.00<\/span>.*$/ do
      before do
        create(
          :measure_condition_component,
          :asvx,
          :with_duty_expression,
          measure_condition:,
          duty_expression_id: '01',
          duty_amount: 500.0,
        )
        create(
          :measure_condition_component,
          :with_duty_expression,
          duty_expression_id: '04',
          measure_condition:,
          duty_amount: 100.0,
        )
      end

      let(:measure) { create(:measure, :excise) }
      let(:measure_condition) { create(:measure_condition, measure:) }
    end

    it_behaves_like 'a measure condition presented duty expression', %r{<span>100.00</span>.*} do
      before do
        create(
          :measure_condition_component,
          :with_duty_expression,
          measure_condition:,
          duty_amount: 100.0,
        )
      end

      let(:measure) { create(:measure) }
      let(:measure_condition) { create(:measure_condition, measure:, condition_duty_amount: 0.01) }
    end
  end

  describe '#requirement_duty_expression' do
    shared_examples 'a presented requirement duty expression' do |expected_duty_amount|
      it { expect(presenter.requirement_duty_expression).to match(expected_duty_amount) }
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
