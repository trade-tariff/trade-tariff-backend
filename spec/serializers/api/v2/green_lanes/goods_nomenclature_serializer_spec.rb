RSpec.describe Api::V2::GreenLanes::GoodsNomenclatureSerializer do
  subject { described_class.new(presented).serializable_hash }

  before do
    measure = subheading.measures.first
    create(:category_assessment, measure:)
    create(:measure, goods_nomenclature: subheading.children.first,
                     measure_type_id: measure.measure_type_id,
                     generating_regulation: measure.generating_regulation)
  end

  let(:subheading) { create :goods_nomenclature, :with_ancestors, :with_children, :with_measures }
  let(:presented) { Api::V2::GreenLanes::GoodsNomenclaturePresenter.new(subheading) }

  let(:expected_pattern) do
    {
      data: {
        attributes: {
          goods_nomenclature_item_id: subheading.goods_nomenclature_item_id.to_s,
          goods_nomenclature_sid: subheading.goods_nomenclature_sid,
          description: be_a(String),
          formatted_description: subheading.formatted_description,
          validity_start_date: subheading.validity_start_date.iso8601,
          validity_end_date: nil,
          description_plain: subheading.description_plain,
          producline_suffix: subheading.producline_suffix,
          parent_sid: subheading.parent.goods_nomenclature_sid,
        },
        relationships: {
          applicable_category_assessments: {
            data: [{
              id: /^[a-f0-9]{32}$/,
              type: eq(:category_assessment),
            }],
          },
          descendant_category_assessments: {
            data: [{
              id: /^[a-f0-9]{32}$/,
              type: eq(:category_assessment),
            }],
          },
          ancestors: {
            data: [
              {
                id: subheading.parent.parent.goods_nomenclature_sid.to_s,
                type: eq(:goods_nomenclature),
              },
              {
                id: subheading.parent.goods_nomenclature_sid.to_s,
                type: eq(:goods_nomenclature),
              },
            ],
          },
          descendants: {
            data: [
              {
                id: subheading.descendants.first.goods_nomenclature_sid.to_s,
                type: eq(:goods_nomenclature),
              },
              {
                id: subheading.descendants.second.goods_nomenclature_sid.to_s,
                type: eq(:goods_nomenclature),
              },
            ],
          },
        },
      },
    }
  end

  it { is_expected.to include_json(expected_pattern) }
end
