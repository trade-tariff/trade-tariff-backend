RSpec.describe Api::V2::Csv::GoodsNomenclatureSerializer do
  describe '#serializable_array' do
    subject(:serializable_array) { described_class.new(serializable).serializable_array }

    let(:serializable) { [goods_nomenclature] }

    let(:goods_nomenclature) { build(:heading) }

    it 'serializes correctly' do
      expect(serializable_array).to eq(
        [
          %i[
            goods_nomenclature_sid
            goods_nomenclature_item_id
            number_indents
            description
            producline_suffix
            href
          ],
          [
            goods_nomenclature.goods_nomenclature_sid,
            goods_nomenclature.goods_nomenclature_item_id,
            0,
            '',
            '80',
            "/api/v2/headings/#{goods_nomenclature.short_code}",
          ],
        ],
      )
    end
  end
end
