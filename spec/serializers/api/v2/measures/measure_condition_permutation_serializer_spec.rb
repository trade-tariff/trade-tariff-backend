RSpec.describe Api::V2::Measures::MeasureConditionPermutationSerializer do
  subject(:serializer) { described_class.new permutation }

  let(:permutation) { MeasureConditionPermutations::Permutation.new conditions }
  let(:measure) { create :measure, :with_measure_conditions }
  let(:conditions) { measure.measure_conditions.to_a }

  describe '#serializable_hash' do
    subject { serializer.serializable_hash.as_json }

    let :expected do
      {
        data: {
          id: permutation.id.to_s,
          type: 'measure_condition_permutation',
          relationships: {
            measure_conditions: {
              data: conditions.map do |condition|
                {
                  id: condition.measure_condition_sid.to_s,
                  type: 'measure_condition',
                }
              end,
            },
          },
        },
      }.as_json
    end

    it { is_expected.to include_json expected }
  end
end
