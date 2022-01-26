RSpec.describe Api::V2::ValidityDateSerializer do
  subject(:serializable) do
    described_class.new(presented).serializable_hash
  end

  let(:presented) { Api::V2::ValidityDatePresenter.new item }

  context 'with commodity' do
    let(:item) { create :commodity }

    let :expected do
      {
        data: {
          id: presented.validity_date_id,
          type: :validity_date,
          attributes: {
            goods_nomenclature_item_id: presented.goods_nomenclature_item_id,
            validity_start_date: presented.validity_start_date,
            validity_end_date: presented.validity_end_date,
          },
        },
      }
    end

    describe '#serializable_hash' do
      it 'matches the expected hash' do
        expect(serializable).to eql expected
      end
    end
  end

  context 'with heading' do
    let(:item) { create :heading }

    let :expected do
      {
        data: {
          id: presented.validity_date_id,
          type: :validity_date,
          attributes: {
            goods_nomenclature_item_id: presented.goods_nomenclature_item_id,
            validity_start_date: presented.validity_start_date,
            validity_end_date: presented.validity_end_date,
          },
        },
      }
    end

    describe '#serializable_hash' do
      it 'matches the expected hash' do
        expect(serializable).to eql expected
      end
    end
  end
end
