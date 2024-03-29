RSpec.describe MeasureConditionPermutations::Group do
  subject :group do
    described_class.new measure.measure_sid,
                        condition_code,
                        permutations
  end

  let(:measure) { create :measure, :with_measure_conditions }
  let(:condition_code) { 'A' }

  let :permutations do
    measure.measure_conditions.map(
      &MeasureConditionPermutations::Permutation.method(:new)
    )
  end

  it { is_expected.to respond_to :id }
  it { is_expected.to respond_to :condition_code }
  it { is_expected.to have_attributes length: 1 }

  describe '#id' do
    subject { group.id }

    it { is_expected.to eql "#{measure.measure_sid}-A" }
  end

  describe '#permutations' do
    subject { group.permutations }

    it { is_expected.not_to be_empty }
    it { is_expected.to all be_instance_of MeasureConditionPermutations::Permutation }
  end

  describe '#permutation_ids' do
    subject { group.permutation_ids }

    it { is_expected.to have_attributes length: group.permutations.length }
    it { is_expected.to all match %r{\A[0-9a-z]{32}\z} }
  end
end
