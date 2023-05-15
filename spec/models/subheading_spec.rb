RSpec.describe Subheading do
  describe '#commodities' do
    subject(:commodities) do
      subheading.commodities.flat_map do |commodity|
        {
          producline_suffix: commodity.producline_suffix,
          goods_nomenclature_item_id: commodity.goods_nomenclature_item_id,
          number_indents: commodity.number_indents,
        }
      end
    end

    let(:subheading) { described_class.find(goods_nomenclature_item_id: '0101290000', producline_suffix: '80') }

    context 'when there is a full tree' do
      let(:expected_commodities) do
        [
          { producline_suffix: '10', goods_nomenclature_item_id: '0101210000', number_indents: 1 }, # Horses
          { producline_suffix: '80', goods_nomenclature_item_id: '0101290000', number_indents: 2 }, # -- Other < target subheading
          { producline_suffix: '80', goods_nomenclature_item_id: '0101291000', number_indents: 3 }, # ---- For slaughter
          { producline_suffix: '80', goods_nomenclature_item_id: '0101299000', number_indents: 3 }, # ---- Other
        ]
      end

      before do
        # Full tree
        create(:chapter, :with_section, :with_indent, :with_guide, indents: 0, producline_suffix: '80', goods_nomenclature_item_id: '0100000000') # Live animals
        create(:heading, :with_indent, :with_description, indents: 0, producline_suffix: '80', goods_nomenclature_item_id: '0101000000')          # Live horses, asses, mules and hinnies
        create(:commodity, :with_indent, :with_description, indents: 1, producline_suffix: '10', goods_nomenclature_item_id: '0101210000')        # Horses < target subheading
        create(:commodity, :with_indent, :with_description, indents: 2, producline_suffix: '80', goods_nomenclature_item_id: '0101210000')        # -- Pure-bred breeding animals
        create(:commodity, :with_indent, :with_description, indents: 2, producline_suffix: '80', goods_nomenclature_item_id: '0101290000')        # -- Other
        create(:commodity, :with_indent, :with_description, indents: 3, producline_suffix: '80', goods_nomenclature_item_id: '0101291000')        # ---- For slaughter
        create(:commodity, :with_indent, :with_description, indents: 3, producline_suffix: '80', goods_nomenclature_item_id: '0101299000')        # ---- Other
        create(:commodity, :with_indent, :with_description, indents: 1, producline_suffix: '80', goods_nomenclature_item_id: '0101300000')        # Asses
        create(:commodity, :with_indent, :with_description, indents: 1, producline_suffix: '80', goods_nomenclature_item_id: '0101900000')        # Other
      end

      it 'returns the ancestors, the subheading and its children' do
        expect(commodities).to eq(expected_commodities)
      end
    end

    context 'when there are no ancestor or child commodities' do
      before do
        create(
          :heading,
          :with_indent,
          :with_description,
          indents: 0,
          producline_suffix: '80',
          goods_nomenclature_item_id: '0101000000',
        )

        create(
          :commodity,
          :with_indent,
          :with_description,
          indents: 1,
          producline_suffix: '80',
          goods_nomenclature_item_id: '0101290000',
        )
      end

      let(:expected_commodities) do
        [
          {
            producline_suffix: subheading.producline_suffix,
            goods_nomenclature_item_id: subheading.goods_nomenclature_item_id,
            number_indents: subheading.number_indents,
          },
        ]
      end

      # This is not a case we can expect in the wild. This is us being defensive to data mishaps
      it 'returns just the subheading' do
        expect(commodities).to eq(expected_commodities)
      end
    end
  end

  describe '#to_param' do
    subject(:to_param) { described_class.find(goods_nomenclature_item_id: '0101210000', producline_suffix: '10').to_param }

    before { create(:commodity, producline_suffix: '10', goods_nomenclature_item_id: '0101210000') }

    it { is_expected.to eq('0101210000-10') }
  end

  describe '#short_code' do
    context 'when the subheading is a harmonised system code' do
      subject(:short_code) { described_class.find(goods_nomenclature_item_id: '0101210000', producline_suffix: '10').short_code }

      before { create(:commodity, producline_suffix: '10', goods_nomenclature_item_id: '0101210000') }

      it { is_expected.to eq('010121') }
    end

    context 'when the subheading is a combined nomenclature code' do
      subject(:short_code) { described_class.find(goods_nomenclature_item_id: '0101210900', producline_suffix: '10').short_code }

      before { create(:commodity, producline_suffix: '10', goods_nomenclature_item_id: '0101210900') }

      it { is_expected.to eq('01012109') }
    end

    context 'when the subheading is a taric code' do
      subject(:short_code) { described_class.find(goods_nomenclature_item_id: '0101210900', producline_suffix: '80').short_code }

      before { create(:commodity, producline_suffix: '80', goods_nomenclature_item_id: '0101210900') }

      it { is_expected.to eq('0101210900') }
    end
  end

  describe '#goods_nomenclature_class' do
    subject do
      described_class.find(goods_nomenclature_item_id: '0101210000', producline_suffix: '10')
                     .goods_nomenclature_class
    end

    before { create(:commodity, producline_suffix: '10', goods_nomenclature_item_id: '0101210000') }

    it { is_expected.to eq('Subheading') }
  end
end
