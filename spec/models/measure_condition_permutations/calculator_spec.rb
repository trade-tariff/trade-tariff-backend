RSpec.describe MeasureConditionPermutations::Calculator do
  subject(:calculator) { described_class.new measure_with_conditions }

  let(:measure) do
    create(:measure)
      .tap { |m| create :measure_condition, measure_sid: m.measure_sid }
  end

  describe 'filtering measure_conditions' do
    subject :measure_conditions do
      calculator.permutation_groups
                .flat_map(&:permutations)
                .flat_map(&:measure_conditions)
    end

    let(:regular_condition) { measure.measure_conditions.first }

    let :waiver_condition do
      create :measure_condition, :cds_waiver, measure_sid: measure.measure_sid
    end

    let :negative_condition do
      create :measure_condition, :negative, measure_sid: measure.measure_sid
    end

    let :measure_with_conditions do
      regular_condition && waiver_condition && negative_condition

      measure.reload
    end

    it 'includes a regular condition' do
      expect(measure_conditions).to include(regular_condition)
    end

    it 'excludes universal waiver conditions' do
      expect(measure_conditions).not_to include(waiver_condition)
    end

    it 'exlcudes negative action conditions' do
      expect(measure_conditions).not_to include(negative_condition)
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
