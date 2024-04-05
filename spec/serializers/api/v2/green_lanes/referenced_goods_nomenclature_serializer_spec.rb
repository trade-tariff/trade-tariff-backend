RSpec.describe Api::V2::GreenLanes::ReferencedGoodsNomenclatureSerializer do
  subject { described_class.new(presented).serializable_hash.as_json }

  let(:subheading) { create :subheading, :with_description, :with_measures }

  let(:presented) do
    Api::V2::GreenLanes::ReferencedGoodsNomenclaturePresenter.new subheading
  end

  let(:expected_pattern) do
    {
      data: {
        id: subheading.goods_nomenclature_sid.to_s,
        type: 'goods_nomenclature',
        attributes: {
          goods_nomenclature_item_id: subheading.goods_nomenclature_item_id.to_s,
          description: be_a(String),
          number_indents: subheading.number_indents,
          producline_suffix: subheading.producline_suffix,
          validity_start_date: /\d{4}-\d{2}-\d{2}T00:00:00.000Z/,
          validity_end_date: nil,
        },
        relationships: {
          measures: {
            data: [
              { type: 'measure', id: subheading.measures.first.id.to_s },
            ],
          },
        },
      },
    }
  end

  it { is_expected.to include_json(expected_pattern) }
end
