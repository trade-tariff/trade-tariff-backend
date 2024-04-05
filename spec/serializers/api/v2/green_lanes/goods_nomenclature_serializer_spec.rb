RSpec.describe Api::V2::GreenLanes::GoodsNomenclatureSerializer do
  subject { described_class.new(presented).serializable_hash }

  before { create :category_assessment, measure: subheading.measures.first }

  let(:subheading) { create :subheading, :with_parent, :with_measures }
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
        },
        relationships: {
          applicable_category_assessments: {
            data: [{
              id: /^[a-f0-9]{32}$/,
              type: eq(:category_assessment),
            }],
          },
          ancestors: {
            data: [
              {
                id: subheading.parent.goods_nomenclature_sid.to_s,
                type: eq(:goods_nomenclature),
              },
            ],
          },
          measures: {
            data: [
              {
                id: subheading.measures.first.measure_sid.to_s,
                type: eq(:measure),
              },
            ],
          },
        },
      },
    }
  end

  it { is_expected.to include_json(expected_pattern) }
end
