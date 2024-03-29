RSpec.describe Search::GoodsNomenclatureSerializer do
  describe '#serializable_hash' do
    context 'when the goods nomenclature is declarable' do
      subject(:serializable_hash) { described_class.new(goods_nomenclature).serializable_hash }

      let(:goods_nomenclature) { GoodsNomenclature.find(goods_nomenclature_item_id: '0101900000') }

      let(:pattern) do
        {
          id: be_a(Integer),
          short_code: '010190',
          goods_nomenclature_item_id: '0101900000',
          heading_id: '0101',
          chapter_id: '01',
          producline_suffix: '80',
          goods_nomenclature_class: 'Commodity',
          description: 'Horses, other than lemmings',
          description_indexed: 'horses',
          description_indexed_shingled: 'horses',
          formatted_description: 'Horses, other than lemmings',
          search_references: 'chapter search reference heading search reference commodity search reference',
          search_intercept_terms: 'donkey baz',
          ancestors: [
            {
              id: be_a(Integer),
              goods_nomenclature_item_id: '0100000000',
              short_code: '01',
              producline_suffix: '80',
              goods_nomenclature_class: 'Chapter',
              description: 'Live horses, asses, mules and hinnies',
              description_indexed: 'live horses, asses, mules and hinnies',
              validity_start_date: '2020-10-21T00:00:00.000Z',
              validity_end_date: nil,
              declarable: false,
              score: nil,
              chapter_id: '01',
              heading_id: nil,
              formatted_description: 'Live horses, asses, mules and hinnies',
              ancestor_ids: [],
              ancestors: [],
              search_references: 'chapter search reference',
              intercept_terms: '',
            },
            {
              id: be_a(Integer),
              goods_nomenclature_item_id: '0101000000',
              short_code: '0101',
              producline_suffix: '80',
              goods_nomenclature_class: 'Heading',
              description: 'Live animals',
              description_indexed: 'live animals',
              validity_start_date: '2020-10-21T00:00:00.000Z',
              validity_end_date: nil,
              declarable: false,
              score: nil,
              chapter_id: '01',
              heading_id: '0101',
              formatted_description: 'Live animals',
              ancestor_ids: [],
              ancestors: [],
              intercept_terms: '',
            },
          ],
          validity_start_date: '2020-06-29T00:00:00Z',
          validity_end_date: nil,
          ancestor_1_description_indexed: 'live horses, asses, mules and hinnies',
          ancestor_2_description_indexed: 'live animals',
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
          ancestor_1_description_indexed_shingled: 'live horses, asses, mules and hinnies',
          ancestor_2_description_indexed_shingled: 'live animals',
          ancestor_3_description_indexed_shingled: nil,
          ancestor_4_description_indexed_shingled: nil,
          ancestor_5_description_indexed_shingled: nil,
          ancestor_6_description_indexed_shingled: nil,
          ancestor_7_description_indexed_shingled: nil,
          ancestor_8_description_indexed_shingled: nil,
          ancestor_9_description_indexed_shingled: nil,
          ancestor_10_description_indexed_shingled: nil,
          ancestor_11_description_indexed_shingled: nil,
          ancestor_12_description_indexed_shingled: nil,
          ancestor_13_description_indexed_shingled: nil,
          guides: [
            {
              id: 1, title: 'Aircraft parts', image: 'aircraft.png', url: 'https://www.gov.uk/guidance/classifying-aircraft-parts-and-accessories', strapline: 'Get help to classify drones and aircraft parts for import and export.'
            },
          ],
          guide_ids: [1],
          declarable: true,
          filter_animal_type: 'equine animals',
          filter_animal_product_state: 'live',
        }
      end

      before do
        commodity = create(
          :commodity,
          :with_ancestors,
          include_search_references: true,
          goods_nomenclature_item_id: '0101900000',
          producline_suffix: '80',
          validity_start_date: Date.parse('2020-06-29'),
        )

        create(
          :search_reference,
          referenced: commodity,
          title: 'commodity search reference, except something else',
        )
      end

      it { is_expected.to include_json(pattern) }
    end

    context 'when the goods nomenclature is non-declarable' do
      subject(:serializable_hash) { described_class.new(goods_nomenclature).serializable_hash }

      let(:goods_nomenclature) { GoodsNomenclature.find(goods_nomenclature_item_id: '0101000000') }

      let(:pattern) do
        {
          id: be_a(Integer),
          goods_nomenclature_item_id: '0101000000',
          heading_id: '0101',
          chapter_id: '01',
          producline_suffix: '80',
          goods_nomenclature_class: 'Heading',
          description: '',
          description_indexed: nil,
          formatted_description: '',
          search_references: '',
          search_intercept_terms: '',
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

      it { is_expected.to include_json(pattern) }
    end
  end
end
