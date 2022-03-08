RSpec.describe MeasureConditionClassification do
  describe '#measure_condition_class' do
    subject(:measure_condition_class) { described_class.new(measure_condition).measure_condition_class }

    context 'when the measure condition has threshold attributes' do
      let(:measure_condition) { build(:measure_condition, :threshold) }

      it { is_expected.to eq('threshold') }
    end

    context 'when the measure condition has a negative measure action code' do
      let(:measure_condition) { create(:measure_condition, :negative) }

      it { is_expected.to eq('negative') }
    end

    context 'when the measure condition has a document exemption attributes' do
      let(:measure_condition) { build(:measure_condition, :exemption) }

      it { is_expected.to eq('exemption') }
    end

    context 'when the measure condition has a document attributes' do
      let(:measure_condition) { build(:measure_condition, :document) }

      it { is_expected.to eq('document') }
    end

    context 'when the measure condition has an unknown classification' do
      let(:measure_condition) { build(:measure_condition, :unknown) }

      it { is_expected.to eq('unknown') }
    end

    context 'when the measure condition has an excluded cds waiver document' do
      let(:measure_condition) { build(:measure_condition, :cds_waiver) }

      it { is_expected.to eq('unknown') }
    end

    context 'when the measure condition has an excluded other certificates document' do
      let(:measure_condition) { build(:measure_condition, :other_exemption) }

      it { is_expected.to eq('unknown') }
    end
  end
end
