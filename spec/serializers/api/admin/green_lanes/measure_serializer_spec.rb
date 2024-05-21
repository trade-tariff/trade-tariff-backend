RSpec.describe Api::Admin::GreenLanes::MeasureSerializer do
  subject(:serialized) do
    described_class.new(measure).as_json
  end

  let(:measure) { create :green_lanes_measure }

  let :expected do
    {
      data: {
        id: measure.id.to_s,
        type: :green_lanes_measure,
        attributes: {
          category_assessment_id: measure.category_assessment_id,
          goods_nomenclature_item_id: measure.goods_nomenclature_item_id,
          productline_suffix: measure.productline_suffix,
        },
      },
    }
  end

  xdescribe '#serializable_hash' do
    it 'matches the expected hash' do
      expect(serialized).to eq(expected)
    end
  end
end
