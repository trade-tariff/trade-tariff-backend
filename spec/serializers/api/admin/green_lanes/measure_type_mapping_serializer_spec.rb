RSpec.describe Api::Admin::GreenLanes::MeasureTypeMappingSerializer do
  subject(:serialized) do
    described_class.new(imtca).serializable_hash
  end

  let(:imtca) { create :identified_measure_type_category_assessment }

  let :expected do
    {
      data: {
        id: imtca.id.to_s,
        type: :green_lanes_measure_type_mapping,
        attributes: {
          measure_type_id: imtca.measure_type_id,
          theme_id: imtca.theme_id,
        },
        relationships: {
          theme: {
            data: { id: imtca.theme_id.to_s, type: :theme },
          },
        },
      },
    }
  end

  describe '#serializable_hash' do
    it 'matches the expected hash' do
      expect(serialized).to eq(expected)
    end
  end
end
