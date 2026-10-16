RSpec.describe Sequel::Model do
  describe 'association datasets' do
    subject(:cached_association) do
      Commodity.association_reflections[:goods_nomenclature_descriptions][:cache]
    end

    before do
      Commodity.by_code(commodity.goods_nomenclature_item_id)
               .eager(:goods_nomenclature_descriptions)
               .take
    end

    let(:commodity) { create :commodity }

    it 'remain uncached' do
      expect(cached_association).to be_nil
    end
  end

  describe '#take' do
    context 'with matching hash conditions' do
      subject(:taken) { Commodity.take(goods_nomenclature_sid: commodity.goods_nomenclature_sid) }

      let(:commodity) { create(:commodity) }

      before { create(:commodity) }

      it 'returns the matching record' do
        expect(taken).to eq(commodity)
      end
    end

    context 'with hash conditions that match no record' do
      subject(:taken) { Commodity.take(goods_nomenclature_sid: 0) }

      it 'raises record not found' do
        expect { taken }.to raise_error(Sequel::RecordNotFound)
      end
    end

    context 'with a matching block condition' do
      subject(:taken) do
        target_sid = commodity.goods_nomenclature_sid
        Commodity.take { goods_nomenclature_sid =~ target_sid }
      end

      let(:commodity) { create(:commodity) }

      before { create(:commodity) }

      it 'returns the matching record' do
        expect(taken).to eq(commodity)
      end
    end
  end
end
