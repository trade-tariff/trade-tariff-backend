RSpec.describe GreenLanes::SearchSubheadingsService do
  subject(:service) { described_class.new(id) }

  describe '#call' do
    before do
      create(
        :subheading,
        goods_nomenclature_item_id: '0101210000',
        producline_suffix: '80',
      )
    end

    context 'when the good nomenclature id is found' do
      let(:id) { '010121' }

      it { expect(service.call).to be_a(Subheading) }

      it 'return the correct goods nomenclature item id' do
        subheading = service.call

        expect(subheading.goods_nomenclature_item_id).to eq('0101210000')
      end
    end
  end
end
