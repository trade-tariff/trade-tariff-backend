RSpec.describe Subheading do
  it { is_expected.to be_a(Commodity) }

  describe '#commodities' do
    subject(:commodities) { subheading.commodities }

    let(:chapter) { Chapter.by_code('01') }
    let(:heading) { Heading.by_code('0101') }
    let(:subheading) { described_class.find(goods_nomenclature_item_id: '0101210000', producline_suffix: '10') }

    context 'when there is a full tree of ancestor and child commodities' do
      before do
        # Full tree
        create(:chapter, :with_section, :with_indent, indents: 0, producline_suffix: '80', goods_nomenclature_item_id: '0100000000') # Live animals
        create(:heading, :with_indent, :with_description, indents: 0, producline_suffix: '80', goods_nomenclature_item_id: '0101000000') # Live horses, asses, mules and hinnies
        create(:commodity, :with_indent, :with_description, indents: 1, producline_suffix: '10', goods_nomenclature_item_id: '0101210000') # Horses
        create(:commodity, :with_indent, :with_description, indents: 2, producline_suffix: '80', goods_nomenclature_item_id: '0101210000') # -- Pure-bred breeding animals
        create(:commodity, :with_indent, :with_description, indents: 2, producline_suffix: '80', goods_nomenclature_item_id: '0101290000') # -- Other
        create(:commodity, :with_indent, :with_description, indents: 3, producline_suffix: '80', goods_nomenclature_item_id: '0101291000') # ---- For slaughter
        create(:commodity, :with_indent, :with_description, indents: 3, producline_suffix: '80', goods_nomenclature_item_id: '0101299000') # ---- Other
        create(:commodity, :with_indent, :with_description, indents: 1, producline_suffix: '80', goods_nomenclature_item_id: '0101300000') # Asses
        create(:commodity, :with_indent, :with_description, indents: 1, producline_suffix: '80', goods_nomenclature_item_id: '0101900000') # Other
      end

      let(:expected_commodities) do
        [
          chapter,
          heading,
        ]
      end

      it { is_expected.to include(expected_commodities) }
    end

    context 'when there are no ancestor or child commodities' do
      let(:expected_commodities) { [] }

      it { is_expected.to include(expected_commodities) }
    end
  end
end
