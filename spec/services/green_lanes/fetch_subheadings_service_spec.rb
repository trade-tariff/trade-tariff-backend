RSpec.describe GreenLanes::FetchGoodsNomenclatureService do
  subject(:service) { described_class.new(id) }

  describe '#call' do
    before do
      create(:goods_nomenclature, goods_nomenclature_item_id: '0101210000')
      create(:goods_nomenclature, goods_nomenclature_item_id: '0101214200')
      create(:goods_nomenclature, goods_nomenclature_item_id: '0101214264')
    end

    context 'when the ID is 6-digit' do
      let(:id) { '010121' }

      it { expect(service.call).to be_a(GoodsNomenclature) }

      it 'return the correct goods nomenclature item id' do
        goods_nomenclature = service.call

        expect(goods_nomenclature.goods_nomenclature_item_id).to eq('0101210000')
      end
    end

    context 'when the ID is 8-digit' do
      let(:id) { '01012142' }

      it { expect(service.call).to be_a(GoodsNomenclature) }

      it 'return the correct goods nomenclature item id' do
        goods_nomenclature = service.call

        expect(goods_nomenclature.goods_nomenclature_item_id).to eq('0101214200')
      end
    end

    context 'when the ID is 10-digit' do
      let(:id) { '0101214264' }

      it { expect(service.call).to be_a(GoodsNomenclature) }

      it 'return the correct goods nomenclature item id' do
        goods_nomenclature = service.call

        expect(goods_nomenclature.goods_nomenclature_item_id).to eq('0101214264')
      end
    end

    context 'when the good nomenclature id is not found' do
      let(:id) { '123456' }

      it 'raises record not found exception' do
        expect { described_class.new(id).call }.to raise_error Sequel::RecordNotFound
      end
    end
  end
end
