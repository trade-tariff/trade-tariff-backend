RSpec.describe SuggestionsService do
  subject(:call) { described_class.new.call }

  before do
    create(:search_reference, :with_heading, title: 'gold ore')
    create(:chapter, goods_nomenclature_item_id: '0100000000')
    create(:commodity, goods_nomenclature_item_id: '0101090000')
    create(
      :full_chemical,
      goods_nomenclature: create(
        :heading,
        goods_nomenclature_item_id: '0102000000',
      ),
    )

    create(:chapter, :hidden, goods_nomenclature_item_id: '0200000000')
    create(:heading, :hidden, goods_nomenclature_item_id: '0202000000')
    create(:commodity, :hidden, goods_nomenclature_item_id: '0202090000')
  end

  let(:expected_values) do
    [
      '01',
      '0101',
      '0102',
      '0101090000',
      'gold ore',
      '8028-66-8',
      '0154438-3',
      'mel powder',
    ]
  end

  it { expect(call.map(&:value)).to eq(expected_values) }
end
