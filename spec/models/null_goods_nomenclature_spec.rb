RSpec.describe NullGoodsNomenclature do
  subject(:null_goods_nomenclature) { described_class.new }

  describe 'description fields' do
    it 'returns the existing fallback values', :aggregate_failures do
      expect(null_goods_nomenclature.description).to eq('')
      expect(null_goods_nomenclature.description_html).to be_nil
      expect(null_goods_nomenclature.description_indexed).to be_nil
      expect(null_goods_nomenclature.description_plain).to be_nil
      expect(null_goods_nomenclature.formatted_description).to be_nil
      expect(null_goods_nomenclature.csv_formatted_description).to be_nil
      expect(null_goods_nomenclature.consigned_from).to be_nil
    end
  end

  it 'has no short code' do
    expect(null_goods_nomenclature.short_code).to be_nil
  end
end
