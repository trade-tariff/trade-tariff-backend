RSpec.describe Api::V2::Measures::MeasureConditionPermutationGroupSerializer do
  subject(:serializer) { described_class.new group }

  let :group do
    MeasureConditionPermutations::Group.new measure.measure_sid,
                                            'A',
                                            permutations
  end

  let(:measure) { create :measure, :with_measure_conditions }
  let(:conditions) { measure.measure_conditions.to_a }

  let :permutations do
    conditions.map(&MeasureConditionPermutations::Permutation.method(:new))
  end

  describe '#serializable_hash' do
    subject { serializer.serializable_hash.as_json }

    let :expected do
      {
        data: {
          id: group.id.to_s,
          type: 'measure_condition_permutation_group',
          attributes: {
            condition_code: 'A',
          },
          relationships: {
            'permutations': {
              data: [
                {
                  id: group.permutations.first.id,
                  type: 'measure_condition_permutation',
                },
              ],
            },
          },
        },
      }.as_json
    end

    it { is_expected.to include_json expected }
  end
end
