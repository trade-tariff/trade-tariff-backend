RSpec.describe Search::GoodsNomenclatureSerializer do
  describe '#serializable_hash' do
    context 'when the goods nomenclature is declarable' do
      subject(:serializable_hash) { described_class.new(goods_nomenclature).serializable_hash }

      let(:goods_nomenclature) { GoodsNomenclature.find(goods_nomenclature_item_id: '0101210000') }

      let(:pattern) do
        {
          id: 3,
          goods_nomenclature_item_id: '0101210000',
          heading_id: '0101',
          chapter_id: '01',
          producline_suffix: '80',
          goods_nomenclature_class: 'Commodity',
          description: 'Horses, other than lemmings',
          description_indexed: 'Horses',
          search_references: 'secret sauce',
          ancestors: [
            {
              description: 'Live horses, asses, mules and hinnies',
              description_indexed: 'Live horses, asses, mules and hinnies',
              goods_nomenclature_class: 'Chapter',
              goods_nomenclature_item_id: '0100000000',
              id: 1,
              producline_suffix: '80',
            },
            {
              description: 'Live animals',
              description_indexed: 'Live animals',
              goods_nomenclature_class: 'Heading',
              goods_nomenclature_item_id: '0101000000',
              id: 2,
              producline_suffix: '80',
            },
          ],
          validity_start_date: '2020-06-29T00:00:00Z',
          validity_end_date: nil,
          ancestor_1_description_indexed: 'Live horses, asses, mules and hinnies',
          ancestor_2_description_indexed: 'Live animals',
          ancestor_3_description_indexed: nil,
          ancestor_4_description_indexed: nil,
          ancestor_5_description_indexed: nil,
          ancestor_6_description_indexed: nil,
          ancestor_7_description_indexed: nil,
          ancestor_8_description_indexed: nil,
          ancestor_9_description_indexed: nil,
          ancestor_10_description_indexed: nil,
          ancestor_11_description_indexed: nil,
          ancestor_12_description_indexed: nil,
          ancestor_13_description_indexed: nil,
          guides: [
            {
              id: 1,
              title: 'Aircraft parts',
              image: 'aircraft.png',
              url: 'https://www.gov.uk/guidance/classifying-aircraft-parts-and-accessories',
              strapline: 'Get help to classify drones and aircraft parts for import and export.',
            },
          ],
          guide_ids: [1],
          filter_animal_product_state: 'live',
          filter_animal_type: 'equine animals',
          declarable: true,
        }
      end

      before do
        commodity = create(
          :commodity,
          :with_ancestors,
          goods_nomenclature_item_id: '0101210000',
          producline_suffix: '80',
          validity_start_date: Date.parse('2020-06-29'),
        )

        create(:search_reference, referenced: commodity, title: 'secret sauce')
      end

      it { is_expected.to eq(pattern) }
    end

    context 'when the goods nomenclature is non-declarable' do
      subject(:serializable_hash) { described_class.new(goods_nomenclature).serializable_hash }

      let(:goods_nomenclature) { GoodsNomenclature.find(goods_nomenclature_item_id: '0101000000') }

      let(:pattern) do
        {
          id: 1,
          goods_nomenclature_item_id: '0101000000',
          heading_id: '0101',
          chapter_id: '01',
          producline_suffix: '80',
          goods_nomenclature_class: 'Heading',
          description: '',
          description_indexed: nil,
          search_references: '',
          ancestors: [],
          validity_start_date: '2020-06-29T00:00:00Z',
          validity_end_date: nil,
          ancestor_1_description_indexed: nil,
          ancestor_2_description_indexed: nil,
          ancestor_3_description_indexed: nil,
          ancestor_4_description_indexed: nil,
          ancestor_5_description_indexed: nil,
          ancestor_6_description_indexed: nil,
          ancestor_7_description_indexed: nil,
          ancestor_8_description_indexed: nil,
          ancestor_9_description_indexed: nil,
          ancestor_10_description_indexed: nil,
          ancestor_11_description_indexed: nil,
          ancestor_12_description_indexed: nil,
          ancestor_13_description_indexed: nil,
          guides: [],
          guide_ids: [],
          declarable: false,
        }
      end

      before do
        create(
          :heading,
          :with_children,
          goods_nomenclature_item_id: '0101000000',
          producline_suffix: '80',
          validity_start_date: Date.parse('2020-06-29'),
        )
      end

      it { is_expected.to eq(pattern) }
    end
  end
end
