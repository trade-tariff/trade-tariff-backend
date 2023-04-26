RSpec.describe SuggestionsService do
  subject(:call) { described_class.new.call }

  before do
    create(:search_reference, :with_heading, title: 'gold Ore')
    create(:chapter, goods_nomenclature_item_id: '0100000000')
    create(:commodity, goods_nomenclature_item_id: '0101090000')
    create(
      :full_chemical,
      goods_nomenclature: create(
        :heading,
        goods_nomenclature_item_id: '0102000000',
      ),
    )
    create(:commodity, :with_children, goods_nomenclature_item_id: '0202070001')
    create(:commodity, :declarable, goods_nomenclature_item_id: '0202080001')

    create(:chapter, :hidden, goods_nomenclature_item_id: '0200000000')
    create(:heading, :hidden, goods_nomenclature_item_id: '0202000000')
    create(:commodity, :hidden, goods_nomenclature_item_id: '0202090000')
  end

  let(:expected_values) do
    [
      '01',
      '0101',
      '010109',
      '0102',
      '0202000001',
      '0202000002',
      '0202000003',
      '0202070001',
      '0202080001',
      'gold ore',
      'mel powder',
      '8028-66-8',
      '0154438-3',
    ]
  end

  let(:expected_goods_nomenclature_classes) do
    %w[
      Chapter
      Heading
      Subheading
      Heading
      Subheading
      Commodity
      Commodity
      Commodity
      Commodity
      Heading
      Heading
      Heading
      Heading
    ]
  end

  it { expect(call.map(&:value)).to eq(expected_values) }

  it { expect(call.map(&:goods_nomenclature_class)).to eq(expected_goods_nomenclature_classes) }
end
