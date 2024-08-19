RSpec.describe GreenLanes::FetchGoodsNomenclatureService do
  subject(:service) { described_class.new(id) }

  describe '#call' do
    before do
      create(:goods_nomenclature, goods_nomenclature_item_id: '0101210000')
      create(:goods_nomenclature, goods_nomenclature_item_id: '0101214200')
      create(:goods_nomenclature, goods_nomenclature_item_id: '0101214264')
      create(:goods_nomenclature, :without_descendants, :non_grouping, goods_nomenclature_item_id: '4909000000')
      create(:goods_nomenclature, :with_descendants, goods_nomenclature_item_id: '0202000000')
    end

    context 'when the ID is 4-digit and declarable' do
      let(:id) { '4909' }

      it { expect(service.call).to be_a(GoodsNomenclature) }

      it 'return the correct goods nomenclature item id' do
        goods_nomenclature = service.call

        expect(goods_nomenclature.goods_nomenclature_item_id).to eq('4909000000')
      end
    end

    context 'when the ID is 4-digit and non declarable' do
      let(:id) { '0202' }

      it 'raises record not found exception' do
        expect { described_class.new(id).call }.to raise_error Sequel::RecordNotFound
      end
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

    context 'when multiple PLS found' do
      before do
        create(:goods_nomenclature, goods_nomenclature_item_id: '0101214264', producline_suffix: '70')
      end

      let(:id) { '0101214264' }

      it { expect(service.call).to be_a(GoodsNomenclature) }

      it 'return the correct goods nomenclature item id' do
        goods_nomenclature = service.call

        expect(goods_nomenclature.producline_suffix).to eq('70')
      end
    end

    context 'when multiple PLS and multiple indents found' do
      before do
        create(:goods_nomenclature, goods_nomenclature_item_id: '0101214264', producline_suffix: '70')
        create(:goods_nomenclature, goods_nomenclature_item_id: '0101214264', producline_suffix: '70', indents: 1)
      end

      let(:id) { '0101214264' }

      it { expect(service.call).to be_a(GoodsNomenclature) }

      it 'return the correct goods nomenclature item id' do
        goods_nomenclature = service.call

        expect(goods_nomenclature.number_indents).to eq(1)
      end
    end

    context 'when the good nomenclature id is not found' do
      let(:id) { '123456' }

      it 'raises record not found exception' do
        expect { described_class.new(id).call }.to raise_error Sequel::RecordNotFound
      end
    end

    context 'when the good nomenclature id is less than four digit' do
      let(:id) { '123' }

      it 'raises record not found exception' do
        expect { described_class.new(id).call }.to raise_error Sequel::RecordNotFound
      end
    end

    context 'when the good nomenclature id is not a subheading' do
      let(:id) { '1234000000' }

      it 'raises record not found exception' do
        expect { described_class.new(id).call }.to raise_error Sequel::RecordNotFound
      end
    end
  end
end
