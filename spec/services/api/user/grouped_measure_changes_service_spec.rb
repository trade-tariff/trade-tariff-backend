RSpec.describe Api::User::GroupedMeasureChangesService do
  subject(:service) { described_class.new(user, date) }

  let(:user) { create(:public_user) }
  let(:date) { Date.current }
  let(:user_commodity_code_sids) { [123_456, 987_654] }

  before do
    allow(user).to receive(:target_ids_for_my_commodities).and_return(user_commodity_code_sids)
  end

  describe '#initialize' do
    it 'sets the user and date' do
      expect(service.instance_variable_get(:@user)).to eq(user)
      expect(service.instance_variable_get(:@date)).to eq(date)
    end

    context 'when no date is provided' do
      subject(:service) { described_class.new(user) }

      it 'defaults to yesterday' do
        expect(service.instance_variable_get(:@date)).to eq(Time.zone.yesterday)
      end
    end
  end

  describe '#call' do
    context 'when no measures exist for user commodity codes' do
      it 'returns an empty array' do
        result = service.call
        expect(result).to eq([])
      end
    end
  end

  describe '#measures_grouped' do
    context 'when measures exist for user commodity codes' do
      let(:eu_area) { create(:geographical_area, :with_description) }
      let(:import_measure_type) { create(:measure_type, :import) }
      let(:export_measure_type) { create(:measure_type, :export) }

      before do
        create(:measure, measure_sid: 100, for_geo_area: eu_area, measure_type_id: import_measure_type.measure_type_id)
        create(:measure, measure_sid: 200, for_geo_area: create(:geographical_area, :with_description), measure_type_id: export_measure_type.measure_type_id)
        create(:tariff_change, type: 'Measure', object_sid: 100, operation_date: date, goods_nomenclature_sid: 123_456)
        create(:tariff_change, type: 'Measure', object_sid: 200, operation_date: date, goods_nomenclature_sid: 987_654)
      end

      it 'returns array of TariffChanges::GroupedMeasureChange objects' do
        result = service.measures_grouped

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result).to(be_all { |r| r.is_a?(TariffChanges::GroupedMeasureChange) })

        import_result = result.find { |r| r.trade_direction == 'import' }
        export_result = result.find { |r| r.trade_direction == 'export' }

        expect(import_result.trade_direction).to eq('import')
        expect(import_result.count).to eq(1)
        expect(import_result.geographical_area_id).to eq(eu_area.geographical_area_id)

        expect(export_result.trade_direction).to eq('export')
        expect(export_result.count).to eq(1)
      end
    end

    context 'when measures have no geographical area' do
      let(:import_measure_type) { create(:measure_type, :import) }

      before do
        create(:measure, measure_sid: 300, for_geo_area: nil, geographical_area_id: nil, geographical_area_sid: nil, measure_type_id: import_measure_type.measure_type_id)
        create(:tariff_change, type: 'Measure', object_sid: 300, operation_date: date, goods_nomenclature_sid: 123_456)
      end

      it 'returns TariffChanges::GroupedMeasureChange object with null geographical area' do
        result = service.measures_grouped
        expect(result).to be_an(Array)
        expect(result.first).to be_a(TariffChanges::GroupedMeasureChange)
        expect(result.first.trade_direction).to eq('import')
        expect(result.first.geographical_area_id).to be_nil
        expect(result.first.count).to eq(1)
      end
    end

    context 'when no measures are returned' do
      it 'returns an empty array' do
        result = service.measures_grouped
        expect(result).to eq([])
      end
    end
  end

  describe '#changedmeasures' do
    context 'when tariff changes and measures exist for user commodity codes' do
      let(:measure1) { create(:measure, measure_sid: 123, geographical_area: create(:geographical_area, :with_description)) }
      let(:measure2) { create(:measure, measure_sid: 456, geographical_area: create(:geographical_area, :with_description)) }

      before do
        create(:tariff_change, type: 'Measure', object_sid: 123, operation_date: date, goods_nomenclature_sid: 123_456)
        create(:tariff_change, type: 'Measure', object_sid: 456, operation_date: date, goods_nomenclature_sid: 987_654)
        measure1
        measure2
      end

      it 'returns measures that match tariff changes for user commodity codes' do
        result = service.changed_measures
        expect(result).to contain_exactly(measure1, measure2)
      end
    end

    context 'when no matching data exists' do
      it 'returns empty dataset when user has no commodity codes' do
        allow(user).to receive(:target_ids_for_my_commodities).and_return([])
        result = service.changed_measures
        expect(result).to be_empty
      end

      it 'returns empty dataset when user commodity codes is nil' do
        allow(user).to receive(:target_ids_for_my_commodities).and_return(nil)
        result = service.changed_measures
        expect(result).to be_empty
      end
    end
  end

  describe 'integration test' do
    it 'returns correctly grouped measures from end to end' do
      eu_area = create(:geographical_area, :with_description)
      us_area = create(:geographical_area, :with_description)

      import_measure_type = create(:measure_type, :import)
      export_measure_type = create(:measure_type, :export)
      both_measure_type = create(:measure_type, :import_and_export)

      create(:measure, measure_sid: 100, for_geo_area: eu_area, measure_type_id: import_measure_type.measure_type_id)
      create(:measure, measure_sid: 200, for_geo_area: us_area, measure_type_id: export_measure_type.measure_type_id)
      create(:measure, measure_sid: 300, for_geo_area: eu_area, measure_type_id: both_measure_type.measure_type_id)

      create(:tariff_change, type: 'Measure', object_sid: 100, operation_date: date, goods_nomenclature_sid: 123_456)
      create(:tariff_change, type: 'Measure', object_sid: 200, operation_date: date, goods_nomenclature_sid: 987_654)
      create(:tariff_change, type: 'Measure', object_sid: 300, operation_date: date, goods_nomenclature_sid: 123_456)

      result = service.call

      expect(result).to be_an(Array)
      expect(result.length).to eq(3)
      expect(result).to(be_all { |r| r.is_a?(TariffChanges::GroupedMeasureChange) })

      import_result = result.find { |r| r.trade_direction == 'import' }
      export_result = result.find { |r| r.trade_direction == 'export' }
      both_result = result.find { |r| r.trade_direction == 'both' }

      expect(import_result.trade_direction).to eq('import')
      expect(import_result.count).to eq(1)
      expect(import_result.geographical_area_id).to eq(eu_area.geographical_area_id)

      expect(export_result.trade_direction).to eq('export')
      expect(export_result.count).to eq(1)
      expect(export_result.geographical_area_id).to eq(us_area.geographical_area_id)

      expect(both_result.trade_direction).to eq('both')
      expect(both_result.count).to eq(1)
      expect(both_result.geographical_area_id).to eq(eu_area.geographical_area_id)
    end
  end
end
