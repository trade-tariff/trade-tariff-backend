RSpec.describe Api::Admin::GreenLanes::MeasureSerializer do
  subject { described_class.new(measure).serializable_hash.as_json }

  let(:measure) { create :green_lanes_measure }

  let :expected_pattern do
    {
      data: {
        id: measure.id.to_s,
        type: 'green_lanes_measure',
        attributes: {
          productline_suffix: measure.productline_suffix,
        },
        relationships: {
          category_assessment: {
            data: { id: measure.category_assessment.id.to_s, type: 'category_assessment' },
          },
          goods_nomenclature: {
            data: { id: measure.goods_nomenclature.goods_nomenclature_sid.to_s, type: 'green_lanes_goods_nomenclature' },
          },
        },
      },
    }
  end

  it { is_expected.to include_json(expected_pattern) }
end
