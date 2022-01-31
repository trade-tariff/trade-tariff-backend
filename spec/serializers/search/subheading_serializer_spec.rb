RSpec.describe Search::SubheadingSerializer do
  describe '#serializable_hash' do
    subject(:serializable_hash) { described_class.new(subheading).serializable_hash }

    let(:subheading) { Subheading.find(goods_nomenclature_item_id: '0101210000') }

    let(:pattern) do
      {
        id: subheading.goods_nomenclature_sid,
        goods_nomenclature_item_id: '0101210000',
        goods_nomenclature_sid: subheading.goods_nomenclature_sid,
        producline_suffix: '10',
        validity_start_date: subheading.validity_start_date,
        validity_end_date: subheading.validity_end_date,
        description: subheading.formatted_description,
        number_indents: subheading.number_indents,
      }.ignore_extra_keys!
    end

    before do
      create(:commodity, producline_suffix: '10', goods_nomenclature_item_id: '0101210000')
    end

    it { is_expected.to match_json_expression(pattern) }
  end
end
