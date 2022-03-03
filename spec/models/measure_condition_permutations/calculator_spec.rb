RSpec.describe MeasureConditionPermutations::Calculator do
  subject(:calculator) { described_class.new measure }

  let(:measure) { create :measure, :with_measure_conditions }

  describe '#permuation_groups' do
    subject { calculator.permutation_groups }

    let(:condition_codes) { measure.measure_conditions.map(&:condition_code).uniq }

    it { is_expected.to all be_instance_of MeasureConditionPermutations::Group }
    it { is_expected.to have_attributes length: condition_codes.length }
  end
end
