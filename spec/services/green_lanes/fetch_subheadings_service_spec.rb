RSpec.describe GreenLanes::FetchSubheadingsService do
  subject(:service) { described_class.new(id) }

  describe '#call' do
    before do
      create(
        :subheading,
        goods_nomenclature_item_id: '0101210000',
        producline_suffix: '80',
      )
      create(
        :subheading,
        goods_nomenclature_item_id: '0101214200',
        producline_suffix: '80',
      )
      create(
        :subheading,
        goods_nomenclature_item_id: '0101214264',
        producline_suffix: '80',
      )
    end

    context 'when the ID is 6-digit' do
      let(:id) { '010121' }

      it { expect(service.call).to be_a(Subheading) }

      it 'return the correct goods nomenclature item id' do
        subheading = service.call

        expect(subheading.goods_nomenclature_item_id).to eq('0101210000')
      end
    end

    context 'when the ID is 8-digit' do
      let(:id) { '01012142' }

      it { expect(service.call).to be_a(Subheading) }

      it 'return the correct goods nomenclature item id' do
        subheading = service.call

        expect(subheading.goods_nomenclature_item_id).to eq('0101214200')
      end
    end

    context 'when the ID is 10-digit' do
      let(:id) { '0101214264' }

      it { expect(service.call).to be_a(Subheading) }

      it 'return the correct goods nomenclature item id' do
        subheading = service.call

        expect(subheading.goods_nomenclature_item_id).to eq('0101214264')
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
