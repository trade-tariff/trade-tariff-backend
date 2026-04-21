RSpec.describe GoodsNomenclatureDescriptionPeriod do
  describe 'oplog primary key' do
    it 'uses goods_nomenclature_description_period_sid, not the geographical_area equivalent' do
      expect(described_class::Operation.primary_key).to include(:goods_nomenclature_description_period_sid)
    end
  end
end
