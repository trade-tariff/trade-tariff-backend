RSpec.describe NullGoodsNomenclature do
  subject(:null_goods_nomenclature) { described_class.new }

  describe '#description' do
    it 'returns empty string' do
      expect(null_goods_nomenclature.description).to eq('')
    end
  end
end
