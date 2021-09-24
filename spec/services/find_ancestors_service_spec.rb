describe FindAncestorsService do
  subject(:service) { described_class.new(goods_nomenclature_item_id).call }

  context 'when the search term is empty' do
    let(:goods_nomenclature_item_id) { '' }

    it 'returns no ancestors' do
      expect(service).to eq([])
    end
  end

  context 'when the search term is fully-qualified (10 chars)' do
    let(:commodity) { create(:commodity) }
    let(:goods_nomenclature_item_id) { commodity.goods_nomenclature_item_id }

    it 'returns the correct ancestors' do
      expected_result = commodity.uptree.pluck(:goods_nomenclature_item_id)

      expect(service).to eq(expected_result)
    end
  end

  context 'when the search term is a Chapter' do
    let(:chapter) { create(:chapter) }
    let(:goods_nomenclature_item_id) { chapter.goods_nomenclature_item_id }

    it 'returns the correct ancestors' do
      expected_result = chapter.uptree.pluck(:goods_nomenclature_item_id)

      expect(service).to eq(expected_result)
    end
  end

  context 'when the search term is a Heading' do
    let(:heading) { create(:heading) }
    let(:goods_nomenclature_item_id) { heading.goods_nomenclature_item_id }

    it 'returns the correct ancestors' do
      expected_result = heading.uptree.pluck(:goods_nomenclature_item_id)

      expect(service).to eq(expected_result)
    end
  end

  context 'when the search term is NOT a Chapter, Heading or fully-qualified Commodity' do
    let(:commodity) { create(:commodity) }
    let(:goods_nomenclature_item_id) { commodity.goods_nomenclature_item_id[0..6] }

    it 'returns no ancestors' do
      expect(service).to eq([])
    end
  end
end
