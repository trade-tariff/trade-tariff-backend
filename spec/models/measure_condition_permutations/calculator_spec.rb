RSpec.describe MeasureConditionPermutations::Calculator do
  subject(:calculator) { described_class.new measure_with_conditions }

  let(:measure) do
    create(:measure)
      .tap { |m| create :measure_condition, measure_sid: m.measure_sid }
  end

  describe '#measure_conditions' do
    subject { calculator.measure_conditions }

    context 'for regular condition' do
      let(:measure_with_conditions) { measure.reload }
      let(:first_condition) { measure.measure_conditions.first }

      it { is_expected.to include(first_condition) }
    end

    context 'with universal waiver conditions do' do
      let :waiver_condition do
        create :measure_condition, :cds_waiver, measure_sid: measure.measure_sid
      end

      let(:measure_with_conditions) { waiver_condition.measure.reload }

      it { is_expected.not_to include(waiver_condition) }
    end

    context 'with negative action conditions do' do
      let :negative_condition do
        create :measure_condition, :negative, measure_sid: measure.measure_sid
      end

      let(:measure_with_conditions) { negative_condition.measure.reload }

      it { is_expected.not_to include(negative_condition) }
    end
  end

  describe '#permutation_groups' do
    subject(:groups) { calculator.permutation_groups }

    context 'with conditions which do not match across condition groups' do
      let(:second_condition) { create :measure_condition, measure_sid: measure.measure_sid }
      let(:calculator) { described_class.new second_condition.measure.reload }

      it 'generates multiple groups' do
        expect(groups).to have_attributes length: 2
      end

      it 'has one permutation per group' do
        expect(groups).to all have_attributes length: 1
      end
    end

    context 'with conditions which match across condition groups' do
      let(:first_condition) { measure.measure_conditions.first }

      let :second_condition do
        create :measure_condition, measure_sid: measure.measure_sid,
                                   certificate_type_code: first_condition.certificate_type_code,
                                   certificate_code: first_condition.certificate_code,
                                   condition_duty_amount: first_condition.condition_duty_amount
      end

      let(:calculator) { described_class.new second_condition.measure.reload }

      it 'has a single group' do
        expect(groups).to have_attributes length: 1
      end

      it 'with a single permutation' do
        expect(groups).to all have_attributes length: 1
      end

      it 'combines the conditions within the permutation' do
        expect(groups.first.permutations.first.length).to be 1
      end
    end
  end
end
