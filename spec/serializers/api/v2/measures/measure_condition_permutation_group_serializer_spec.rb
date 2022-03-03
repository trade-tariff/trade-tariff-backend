RSpec.describe Api::V2::Measures::MeasureConditionPermutationGroupSerializer do
  subject(:serializer) { described_class.new group }

  let :group do
    MeasureConditionPermutations::Group.new measure.measure_sid,
                                            condition_code,
                                            conditions
  end

  let(:measure) { create :measure, :with_measure_conditions }
  let(:condition_code) { 'A' }
  let(:conditions) { measure.measure_conditions.to_a }

  describe '#serializable_hash' do
    subject { serializer.serializable_hash.as_json }

    let :expected do
      {
        data: {
          id: group.id.to_s,
          type: 'measure_condition_permutation_group',
          attributes: {
            condition_code:,
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
