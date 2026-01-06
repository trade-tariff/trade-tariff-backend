RSpec.describe Api::V2::Measures::MeasureConditionComponentPresenter do
  subject(:presenter) { described_class.new(measure_condition_component, measure) }

  describe '#duty_amount' do
    shared_examples 'a measure condition presented duty amount' do |coerced_amount, uncoerced_amount|
      context 'when the coercian date starts' do
        around do |example|
          TimeMachine.at(TradeTariffBackend.excise_alcohol_coercian_starts_from) { example.run }
        end

        it { expect(presenter.duty_amount).to eq(coerced_amount) }
      end

      context 'when before the coercian date starts' do
        around do |example|
          TimeMachine.at(TradeTariffBackend.excise_alcohol_coercian_starts_from - 1.day) { example.run }
        end

        it { expect(presenter.duty_amount).to eq(uncoerced_amount) }
      end
    end

    it_behaves_like 'a measure condition presented duty amount', 1.0, 100.0 do
      let(:measure) { create(:measure, :excise) }
      let(:measure_condition) { create(:measure_condition, measure:) }
      let(:measure_condition_component) { create(:measure_condition_component, :asvx, measure_condition:, duty_amount: 100.0) }
    end

    it_behaves_like 'a measure condition presented duty amount', 100.0, 100.0 do
      let(:measure) { create(:measure) }
      let(:measure_condition) { create(:measure_condition, measure:) }
      let(:measure_condition_component) { create(:measure_condition_component, measure_condition:, duty_amount: 100.0) }
    end

    it_behaves_like 'a measure condition presented duty amount', nil, nil do
      let(:measure) { create(:measure) }
      let(:measure_condition) { create(:measure_condition, measure:) }
      let(:measure_condition_component) { create(:measure_condition_component, measure_condition:, duty_amount: nil) }
    end
  end

  describe '#formatted_duty_expression' do
    shared_examples 'a presented formatted duty expression' do |coerced_amount, uncoerced_amount|
      context 'when the coercian date starts' do
        around do |example|
          TimeMachine.at(TradeTariffBackend.excise_alcohol_coercian_starts_from) { example.run }
        end

        it { expect(presenter.formatted_duty_expression).to match(coerced_amount) }
      end

      context 'when before the coercian date starts' do
        around do |example|
          TimeMachine.at(TradeTariffBackend.excise_alcohol_coercian_starts_from - 1.day) { example.run }
        end

        it { expect(presenter.formatted_duty_expression).to match(uncoerced_amount) }
      end
    end

    it_behaves_like 'a presented formatted duty expression', /^<span>1.00<\/span>.*$/, /^<span>100.00<\/span>.*$/ do
      let(:measure) { create(:measure, :excise) }
      let(:measure_condition) { create(:measure_condition, measure:) }
      let(:measure_condition_component) do
        create(
          :measure_condition_component,
          :asvx,
          :with_duty_expression,
          measure_condition:,
          duty_expression_id: '01',
          monetary_unit_code: 'ZZZ',
          duty_amount: 100.0,
        )
      end
    end

    it_behaves_like 'a presented formatted duty expression', /^<span>100.00<\/span>.*$/, /^<span>100.00<\/span>.*$/ do
      let(:measure) { create(:measure) }
      let(:measure_condition) { create(:measure_condition, measure:) }
      let(:measure_condition_component) do
        create(
          :measure_condition_component,
          :with_duty_expression,
          measure_condition:,
          duty_expression_id: '01',
          monetary_unit_code: 'ZZZ',
          duty_amount: 100.0,
        )
      end
    end
  end

  describe '#verbose_duty_expression' do
    shared_examples 'a presented verbose duty expression' do |coerced_amount, uncoerced_amount|
      context 'when the coercian date starts' do
        around do |example|
          TimeMachine.at(TradeTariffBackend.excise_alcohol_coercian_starts_from) { example.run }
        end

        it { expect(presenter.verbose_duty_expression).to match(coerced_amount) }
      end

      context 'when before the coercian date starts' do
        around do |example|
          TimeMachine.at(TradeTariffBackend.excise_alcohol_coercian_starts_from - 1.day) { example.run }
        end

        it { expect(presenter.verbose_duty_expression).to match(uncoerced_amount) }
      end
    end

    it_behaves_like 'a presented verbose duty expression', /^1\.00.*$/, /^100\.00.*$/ do
      let(:measure) { create(:measure, :excise) }
      let(:measure_condition) { create(:measure_condition, measure:) }
      let(:measure_condition_component) do
        create(
          :measure_condition_component,
          :asvx,
          :with_duty_expression,
          measure_condition:,
          duty_expression_id: '01',
          monetary_unit_code: 'ZZZ',
          duty_amount: 100.0,
        )
      end
    end

    it_behaves_like 'a presented verbose duty expression', /^100\.00.*$/, /^100\.00.*$/ do
      let(:measure) { create(:measure) }
      let(:measure_condition) { create(:measure_condition, measure:) }
      let(:measure_condition_component) do
        create(
          :measure_condition_component,
          :with_duty_expression,
          measure_condition:,
          duty_expression_id: '01',
          monetary_unit_code: 'ZZZ',
          duty_amount: 100.0,
        )
      end
    end
  end

  describe '#duty_expression_str' do
    shared_examples 'a presented duty expression string' do |coerced_amount, uncoerced_amount|
      context 'when the coercian date starts' do
        around do |example|
          TimeMachine.at(TradeTariffBackend.excise_alcohol_coercian_starts_from) { example.run }
        end

        it { expect(presenter.duty_expression_str).to match(coerced_amount) }
      end

      context 'when before the coercian date starts' do
        around do |example|
          TimeMachine.at(TradeTariffBackend.excise_alcohol_coercian_starts_from - 1.day) { example.run }
        end

        it { expect(presenter.duty_expression_str).to match(uncoerced_amount) }
      end
    end

    it_behaves_like 'a presented duty expression string', /^1\.00.*$/, /^100\.00.*$/ do
      let(:measure) { create(:measure, :excise) }
      let(:measure_condition) { create(:measure_condition, measure:) }
      let(:measure_condition_component) do
        create(
          :measure_condition_component,
          :asvx,
          :with_duty_expression,
          measure_condition:,
          duty_expression_id: '01',
          monetary_unit_code: 'ZZZ',
          duty_amount: 100.0,
        )
      end
    end

    it_behaves_like 'a presented duty expression string', /^100\.00.*$/, /^100\.00.*$/ do
      let(:measure) { create(:measure) }
      let(:measure_condition) { create(:measure_condition, measure:) }
      let(:measure_condition_component) do
        create(
          :measure_condition_component,
          :with_duty_expression,
          measure_condition:,
          duty_expression_id: '01',
          monetary_unit_code: 'ZZZ',
          duty_amount: 100.0,
        )
      end
    end
  end

  describe '#presented_duty_expression' do
    context 'when the component is a Small Producers Quotient component' do
      let(:measure) { create(:measure) }
      let(:measure_condition) { create(:measure_condition, measure:) }
      let(:measure_condition_component) do
        create(
          :measure_condition_component,
          :with_duty_expression,
          :with_measurement_unit,
          duty_expression_id: '02',
          measure_condition:,
          measurement_unit_code: 'SPQ',
          monetary_unit_code: 'GBP',
          duty_amount: 1.0,
        )
      end

      it { expect(presenter.presented_duty_expression).to eq('- £1.00  / for each litre of pure alcohol, multiplied by the SPR discount') }
    end

    context 'when the component is not a Small Producers Quotient component' do
      let(:measure) { create(:measure) }
      let(:measure_condition) { create(:measure_condition, measure:) }
      let(:measure_condition_component) do
        create(
          :measure_condition_component,
          :asvx,
          :with_duty_expression,
          measure_condition:,
          duty_expression_id: '01',
          monetary_unit_code: 'GBP',
          duty_amount: 500.0,
        )
      end

      it { expect(presenter.presented_duty_expression).to eq('<span>500.00</span> GBP') }
    end
  end

  describe '.wrap' do
    subject(:wrapped) { described_class.wrap(measure_condition_components, measure) }

    let(:measure) { create(:measure) }
    let(:measure_condition) { create(:measure_condition, measure:) }
    let(:measure_condition_components) { create_list(:measure_condition_component, 2, measure_condition:) }

    it 'returns an array of wrapped measure condition components' do
      expect(wrapped).to all(be_a(described_class))
    end
  end
end
