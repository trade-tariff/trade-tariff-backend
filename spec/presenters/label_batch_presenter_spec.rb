RSpec.describe LabelBatchPresenter do
  subject(:presenter) { described_class.new(batch) }

  let(:batch) { [goods_nomenclature1, goods_nomenclature2] }
  let(:goods_nomenclature1) do
    instance_double(
      GoodsNomenclature,
      goods_nomenclature_item_id: '0101210000',
      classification_description: 'Pure-bred breeding animals - Horses',
      as_json: { 'goods_nomenclature_item_id' => '0101210000' },
    )
  end
  let(:goods_nomenclature2) do
    instance_double(
      GoodsNomenclature,
      goods_nomenclature_item_id: '0101290000',
      classification_description: 'Other horses',
      as_json: { 'goods_nomenclature_item_id' => '0101290000' },
    )
  end

  describe '#goods_nomenclature_for' do
    it 'returns the goods nomenclature matching the item id' do
      result = presenter.goods_nomenclature_for('0101210000')
      expect(result).to eq(goods_nomenclature1)
    end

    it 'returns the second goods nomenclature when searching for its id' do
      result = presenter.goods_nomenclature_for('0101290000')
      expect(result).to eq(goods_nomenclature2)
    end

    it 'returns nil when no match is found' do
      result = presenter.goods_nomenclature_for('9999999999')
      expect(result).to be_nil
    end
  end

  describe '#to_json' do
    it 'returns a JSON array of presented goods nomenclatures' do
      result = JSON.parse(presenter.to_json)

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
    end

    it 'includes goods_nomenclature_item_id for each item' do
      result = JSON.parse(presenter.to_json)

      expect(result[0]['goods_nomenclature_item_id']).to eq('0101210000')
      expect(result[1]['goods_nomenclature_item_id']).to eq('0101290000')
    end

    it 'includes original_description for each item' do
      result = JSON.parse(presenter.to_json)

      expect(result[0]['original_description']).to eq('Pure-bred breeding animals - Horses')
      expect(result[1]['original_description']).to eq('Other horses')
    end
  end

  describe 'delegation' do
    it 'delegates array methods to the batch' do
      expect(presenter.size).to eq(2)
      expect(presenter.first).to eq(goods_nomenclature1)
      expect(presenter.last).to eq(goods_nomenclature2)
    end

    it 'is enumerable' do
      expect(presenter.map(&:goods_nomenclature_item_id)).to eq(%w[0101210000 0101290000])
    end
  end
end
