RSpec.describe Api::V2::GoodsNomenclatures::GoodsNomenclatureListSerializer do
  describe '#serializable_hash' do
    subject(:serializable) { described_class.new(gn).serializable_hash[:data] }

    let(:gn) { build :commodity }

    it { is_expected.to include type: :goods_nomenclature }
    it { is_expected.to include id: gn.goods_nomenclature_sid.to_s }

    describe 'attributes' do
      subject { serializable[:attributes] }

      let :attribute_keys do
        %i[
          goods_nomenclature_item_id
          goods_nomenclature_sid
          producline_suffix
          description
          number_indents
          href
        ]
      end

      it { is_expected.to have_attributes keys: attribute_keys }
      it { is_expected.to include goods_nomenclature_item_id: gn.goods_nomenclature_item_id }
      it { is_expected.to include goods_nomenclature_sid: gn.goods_nomenclature_sid }
      it { is_expected.to include producline_suffix: gn.producline_suffix }
      it { is_expected.to include description: gn.description }
      it { is_expected.to include number_indents: gn.number_indents }
      it { is_expected.to include href: "/uk/api/commodities/#{gn.goods_nomenclature_item_id}" }
    end
  end
end
