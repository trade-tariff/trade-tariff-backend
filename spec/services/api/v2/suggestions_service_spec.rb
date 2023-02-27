RSpec.describe Api::V2::SuggestionsService do
  subject(:call) { described_class.new.perform }

  before do
    create(:search_reference, :with_heading, title: 'gold ore')
    create(:chapter, goods_nomenclature_item_id: '0100000000')
    create(:heading, goods_nomenclature_item_id: '0101000000')
    create(:commodity, goods_nomenclature_item_id: '0101090000')

    create(:chapter, :hidden, goods_nomenclature_item_id: '0200000000')
    create(:heading, :hidden, goods_nomenclature_item_id: '0202000000')
    create(:commodity, :hidden, goods_nomenclature_item_id: '0202090000')
  end

  it { expect(call.map(&:value)).to eq(['01', '0101', '0101', '0101090000', 'gold ore']) }
end
