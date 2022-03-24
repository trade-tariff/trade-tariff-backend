RSpec.describe MeasureConditionPermutations::Calculators::Unmatched do
  subject :calculator do
    described_class.new measure.measure_sid,
                        second.measure.reload.measure_conditions
  end

  let(:measure) { create :measure }
  let(:first) { create :measure_condition, measure_sid: measure.measure_sid }
  let(:second) { create :measure_condition, measure_sid: first.measure.measure_sid }

  describe '#permutation_groups' do
    subject(:groups) { calculator.permutation_groups }

    it { is_expected.to have_attributes length: 2 }
    it { is_expected.to all have_attributes length: 1 }

    it 'splits the conditions into separate permuation groups' do
      expect(groups.first.permutations.first.measure_condition_ids).not_to \
        eql groups.second.permutations.first.measure_condition_ids
    end
  end
end
