RSpec.describe PublicUsers::NullCommodity do
  subject(:null_commodity) { described_class.new(goods_nomenclature_item_id:) }

  let(:goods_nomenclature_item_id) { '9999999999' }

  it 'returns fallback commodity values', :aggregate_failures do
    expect(null_commodity.goods_nomenclature_item_id).to eq(goods_nomenclature_item_id)
    expect(null_commodity.id).to eq("null_#{goods_nomenclature_item_id}")
    expect(null_commodity.classification_description).to eq('')
    expect(null_commodity.validity_end_date).to be_nil
    expect(null_commodity.chapter_short_code).to be_nil
    expect(null_commodity.heading).to be_nil
  end
end
