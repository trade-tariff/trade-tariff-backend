RSpec.describe Api::V2::GreenLanes::ReferencedGoodsNomenclatureSerializer do
  subject { described_class.new(subheading).serializable_hash.as_json }

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
          validity_start_date: subheading.validity_start_date.to_s,
          validity_end_date: nil
        }
      }
    }
  end

  let(:subheading) { create :subheading, :with_description }

  it { is_expected.to include_json(expected_pattern) }
end
