RSpec.describe Api::Admin::Csv::GoodsNomenclatureSerializer do
  subject(:serialized) { described_class.new(serializable).serialized_csv }

  let(:serializable) { [create(:chapter)] }

  describe '#serialized_csv' do
    it 'includes the correct headers' do
      expected_header = 'SID,Commodity code,Product line suffix,Description,Start date,End date,Indentation,End line,Class,ItemIDPlusPLS,Hierarchy'

      expect(serialized).to include(expected_header)
    end
  end
end
