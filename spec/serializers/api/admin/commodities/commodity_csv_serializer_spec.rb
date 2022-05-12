RSpec.describe Api::Admin::Commodities::CommodityCsvSerializer do
  subject(:serialized) { described_class.new(serializable).serialized_csv }

  let(:serializable) do
    [{
      goods_nomenclature_sid: 1,
      goods_nomenclature_item_id: '0100000000',
      producline_suffix: '80',
      validity_start_date: '1971-12-31T00:00:00.000Z',
      validity_end_date: '1022-01-01T00:00:00.000Z',
      description: 'LIVE ANIMALS',
      number_indents: 0,
      chapter: '01',
      node: '01',
      leaf: '0',
      significant_digits: 2,
    }]
  end

  describe '#serialized_csv' do
    it 'includes the correct header' do
      expect(serialized).to include(
        "SID,Commodity code,Product line suffix,Description,Start date,End date,Indentation,End line,ItemIDPlusPLS\n",
      )
    end

    it 'serializes correctly the fields' do
      expect(serialized).to include(
        '1,0100000000,80,LIVE ANIMALS,1971-12-31,1022-01-01,0,0,0100000000_80',
      )
    end
  end
end
