RSpec.describe Api::V2::Measures::MeasureConditionComponentPresenter do
  describe '#duty_amount' do
    subject(:duty_amount) { described_class.new(measure, measure_condition_component, index).duty_amount }

    shared_examples 'a measure condition presented duty amount' do |expected_duty_amount|
      it { is_expected.to eq(expected_duty_amount) }
    end

    it_behaves_like 'a measure condition presented duty amount', 1.0 do
      before do
        create(:measure_condition_component, :asvx, measure_condition:)
      end

      let(:measure) { create(:measure, :excise) }
      let(:measure_condition) { create(:measure_condition, measure:) }
      let(:measure_condition_component) { create(:measure_condition_component, measure_condition:, duty_amount: 100.0) }
      let(:index) { 0 }
    end

    it_behaves_like 'a measure condition presented duty amount', 100.0 do
      let(:measure) { create(:measure) }
      let(:measure_condition) { create(:measure_condition, measure:) }
      let(:measure_condition_component) { create(:measure_condition_component, measure_condition:, duty_amount: 100.0) }
      let(:index) { 1 }
    end

    it_behaves_like 'a measure condition presented duty amount', nil do
      let(:measure) { create(:measure) }
      let(:measure_condition) { create(:measure_condition, measure:) }
      let(:measure_condition_component) { create(:measure_condition_component, measure_condition:, duty_amount: nil) }
      let(:index) { 1 }
    end
  end

  describe '#formatted_duty_expression' do
    subject(:formatted_duty_expression) { described_class.new(measure, measure_condition_component, index).formatted_duty_expression }

    shared_examples 'a presented formatted duty expression' do |expected_duty_amount|
      it { is_expected.to match(expected_duty_amount) }
    end

    it_behaves_like 'a presented formatted duty expression', /^<span>1.00<\/span>.*$/ do
      before do
        create(:measure_condition_component, :asvx, measure_condition:)
      end

      let(:measure) { create(:measure, :excise) }
      let(:measure_condition) { create(:measure_condition, measure:) }
      let(:measure_condition_component) { create(:measure_condition_component, :with_duty_expression, measure_condition:, duty_amount: 100.0) }
      let(:index) { 0 }
    end

    it_behaves_like 'a presented formatted duty expression', /^<span>100.00<\/span>.*$/ do
      let(:measure) { create(:measure) }
      let(:measure_condition) { create(:measure_condition, measure:) }
      let(:measure_condition_component) { create(:measure_condition_component, :with_duty_expression, measure_condition:, duty_amount: 100.0) }
      let(:index) { 1 }
    end
  end

  describe '#verbose_duty_expression' do
    subject(:verbose_duty_expression) { described_class.new(measure, measure_condition_component, index).verbose_duty_expression }

    shared_examples 'a presented verbose duty expression' do |expected_duty_amount|
      it { is_expected.to match(expected_duty_amount) }
    end

    it_behaves_like 'a presented verbose duty expression', /^1\.00.*$/ do
      before do
        create(:measure_condition_component, :asvx, measure_condition:)
      end

      let(:measure) { create(:measure, :excise) }
      let(:measure_condition) { create(:measure_condition, measure:) }
      let(:measure_condition_component) { create(:measure_condition_component, :with_duty_expression, measure_condition:, duty_amount: 100.0) }
      let(:index) { 0 }
    end

    it_behaves_like 'a presented verbose duty expression', /^100\.00.*$/ do
      let(:measure) { create(:measure) }
      let(:measure_condition) { create(:measure_condition, measure:) }
      let(:measure_condition_component) { create(:measure_condition_component, :with_duty_expression, measure_condition:, duty_amount: 100.0) }
      let(:index) { 1 }
    end
  end

  describe '#duty_expression_str' do
    subject(:duty_expression_str) { described_class.new(measure, measure_condition_component, index).duty_expression_str }

    shared_examples 'a presented duty expression string' do |expected_duty_amount|
      it { is_expected.to match(expected_duty_amount) }
    end

    it_behaves_like 'a presented duty expression string', /^1\.00.*$/ do
      before do
        create(:measure_condition_component, :asvx, measure_condition:)
      end

      let(:measure) { create(:measure, :excise) }
      let(:measure_condition) { create(:measure_condition, measure:) }
      let(:measure_condition_component) { create(:measure_condition_component, :with_duty_expression, measure_condition:, duty_amount: 100.0) }
      let(:index) { 0 }
    end

    it_behaves_like 'a presented duty expression string', /^100\.00.*$/ do
      let(:measure) { create(:measure) }
      let(:measure_condition) { create(:measure_condition, measure:) }
      let(:measure_condition_component) { create(:measure_condition_component, :with_duty_expression, measure_condition:, duty_amount: 100.0) }
      let(:index) { 1 }
    end
  end

  describe '.wrap' do
    subject(:wrapped) { described_class.wrap(measure, measure_condition_components) }

    let(:measure) { create(:measure) }
    let(:measure_condition) { create(:measure_condition, measure:) }
    let(:measure_condition_components) { create_list(:measure_condition_component, 2, measure_condition:) }

    it 'returns an array of wrapped measure condition components' do
      expect(wrapped).to all(be_a(described_class))
    end
  end
end
