RSpec.describe Api::User::GroupedMeasureCommodityChangesService do
  subject(:service) { described_class.new(grouped_measure_change_id, id, date) }

  let(:grouped_measure_change_id) { 'import_2054__0407210000' }
  let(:id) { 'some_id' }
  let(:date) { '2025-10-28' }

  describe '#call' do
    context 'when commodity exists' do
      let(:commodity) { create(:goods_nomenclature, goods_nomenclature_item_id: '0407210000') }

      before { commodity } # Ensure commodity is created

      it 'returns a GroupedMeasureCommodityChange with commodity loaded' do
        result = service.call

        expect(result).to be_a(TariffChanges::GroupedMeasureCommodityChange)
        expect(result.goods_nomenclature_item_id).to eq('0407210000')
        expect(result.grouped_measure_change_id).to eq('import_2054_')
        expect(result.commodity).to be_present
        expect(result.commodity.goods_nomenclature_item_id).to eq('0407210000')
        expect(result.commodity_id).to eq(result.commodity.id)
      end
    end

    context 'when commodity does not exist' do
      let(:grouped_measure_change_id) { 'import_2054__9999999999' }

      it 'returns a GroupedMeasureCommodityChange with nil commodity' do
        result = service.call

        expect(result).to be_a(TariffChanges::GroupedMeasureCommodityChange)
        expect(result.goods_nomenclature_item_id).to eq('9999999999')
        expect(result.commodity).to be_nil
        expect(result.commodity_id).to be_nil
      end
    end

    context 'with different ID format' do
      let(:grouped_measure_change_id) { 'export_GB__1234567890' }
      let(:other_commodity) { create(:goods_nomenclature, goods_nomenclature_item_id: '1234567890') }

      before { other_commodity } # Ensure commodity is created

      it 'parses the ID correctly' do
        result = service.call

        expect(result.goods_nomenclature_item_id).to eq('1234567890')
        expect(result.grouped_measure_change_id).to eq('export_GB_')
        expect(result.commodity).to be_present
        expect(result.commodity.goods_nomenclature_item_id).to eq('1234567890')
      end
    end
  end

  describe '#initialize' do
    it 'sets the attributes correctly' do
      expect(service.grouped_measure_change_id).to eq(grouped_measure_change_id)
      expect(service.id).to eq(id)
      expect(service.date).to eq(date)
    end

    context 'when date is not provided' do
      subject(:service) { described_class.new(grouped_measure_change_id, id) }

      it 'defaults to yesterday' do
        expect(service.date).to eq(Time.zone.yesterday)
      end
    end
  end
end
