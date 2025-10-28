RSpec.describe DeltaReportService::ExcludedGeographicalAreaChanges do
  let(:date) { Date.parse('2024-08-11') }
  let(:geographical_area) { build(:geographical_area, :with_description, geographical_area_id: 'GB') }
  let(:measure) { build(:measure, goods_nomenclature_item_id: '0101000000', operation_date: date) }
  let(:excluded_geo_area) do
    build(:measure_excluded_geographical_area,
          measure_sid: measure.measure_sid,
          excluded_geographical_area: 'IE',
          operation_date: date)
  end
  let(:instance) { described_class.new(excluded_geo_area, date) }

  before do
    allow(excluded_geo_area).to receive_messages(
      measure: measure,
      geographical_area: geographical_area,
    )
    allow(instance).to receive(:get_changes)
    allow(Measure.operation_klass).to receive_message_chain(:where, :any?).and_return(false)
  end

  describe '.collect' do
    let(:excluded_geo_area_operation1) { instance_double(MeasureExcludedGeographicalArea.operation_klass, oid: 1, record_from_oplog: excluded_geo_area) }
    let(:excluded_geo_area_operation2) { instance_double(MeasureExcludedGeographicalArea.operation_klass, oid: 2, record_from_oplog: excluded_geo_area) }
    let(:excluded_geo_area_operations) { [excluded_geo_area_operation1, excluded_geo_area_operation2] }

    before do
      allow(MeasureExcludedGeographicalArea.operation_klass).to receive(:where).with(operation_date: date).and_return(excluded_geo_area_operations)
    end

    it 'finds excluded geographical area operations for the given date and returns analyzed changes' do
      # Mock the map behavior which creates instances and calls analyze
      allow(excluded_geo_area_operations).to receive_messages(
        map: [{ type: 'ExcludedGeographicalArea' }, nil],
        compact: [{ type: 'ExcludedGeographicalArea' }],
      )

      result = described_class.collect(date)

      expect(MeasureExcludedGeographicalArea.operation_klass).to have_received(:where).with(operation_date: date)
      expect(result).to eq([{ type: 'ExcludedGeographicalArea' }])
    end

    it 'compacts the results to remove nil values' do
      allow(excluded_geo_area_operations).to receive_messages(
        map: [nil, { type: 'ExcludedGeographicalArea' }],
        compact: [{ type: 'ExcludedGeographicalArea' }],
      )

      result = described_class.collect(date)

      expect(result).to eq([{ type: 'ExcludedGeographicalArea' }])
    end
  end

  describe '#object_name' do
    it 'returns the correct object name' do
      expect(instance.object_name).to eq('Excluded Geo Area')
    end
  end

  describe '#analyze' do
    before do
      allow(instance).to receive_messages(
        measure_type: 'Third country duty',
        import_export: 'Import',
        geo_area: 'United Kingdom (GB)',
        additional_code: nil,
      )
    end

    context 'when no measure operations with operation U are found' do
      before do
        allow(Measure.operation_klass).to receive_message_chain(:where, :any?).and_return(false)
      end

      it 'returns nil (filters out when no update operations found)' do
        expect(instance.analyze).to be_nil
      end
    end

    context 'when measure operations with operation U are found' do
      before do
        allow(Measure.operation_klass).to receive_message_chain(:where, :any?).and_return(true)
        allow(TimeMachine).to receive(:at).with(excluded_geo_area.operation_date).and_yield
      end

      it 'returns the correct analysis hash' do
        result = instance.analyze

        expect(result).to eq({
          type: 'ExcludedGeographicalArea',
          measure_sid: excluded_geo_area.measure_sid,
          measure_type: 'Third country duty',
          import_export: 'Import',
          geo_area: 'United Kingdom (GB)',
          date_of_effect: date,
          description: 'Excluded Geo Area added',
          change: 'Excluded IE',
        })
      end

      it 'uses TimeMachine with the record operation_date' do
        instance.analyze

        expect(TimeMachine).to have_received(:at).with(excluded_geo_area.operation_date)
      end
    end

    context 'with different excluded geographical area values' do
      before do
        allow(Measure.operation_klass).to receive_message_chain(:where, :any?).and_return(true)
        allow(TimeMachine).to receive(:at).with(excluded_geo_area.operation_date).and_yield
      end

      it 'includes the excluded geographical area in the change description' do
        allow(excluded_geo_area).to receive(:excluded_geographical_area).and_return('FR')
        result = instance.analyze
        expect(result[:change]).to eq('Excluded FR')
      end

      it 'handles multi-character geographical area codes' do
        allow(excluded_geo_area).to receive(:excluded_geographical_area).and_return('EU')
        result = instance.analyze
        expect(result[:change]).to eq('Excluded EU')
      end
    end
  end

  describe 'MeasurePresenter integration' do
    let(:measure_type) { build(:measure_type, measure_type_id: '103') }
    let(:measure_type_description) { build(:measure_type_description, measure_type_id: '103', description: 'Third country duty') }
    let(:additional_code) { build(:additional_code, additional_code: 'A123') }

    before do
      allow(measure).to receive_messages(
        measure_type: measure_type,
        additional_code: additional_code,
      )
      allow(measure_type).to receive(:measure_type_description).and_return(measure_type_description)
      allow(Measure.operation_klass).to receive_message_chain(:where, :any?).and_return(true)
      allow(TimeMachine).to receive(:at).with(excluded_geo_area.operation_date).and_yield
    end

    it 'uses MeasurePresenter methods for formatting' do
      allow(instance).to receive_messages(
        get_changes: nil,
        geo_area: 'United Kingdom (GB)',
      )

      result = instance.analyze

      expect(result[:measure_type]).to include(measure_type_description.description)
      expect(result[:additional_code]).to be_nil
      expect(result[:geo_area]).to include(geographical_area.geographical_area_id)
    end
  end

  describe 'edge cases' do
    before do
      allow(Measure.operation_klass).to receive_message_chain(:where, :any?).and_return(true)
      allow(TimeMachine).to receive(:at).with(excluded_geo_area.operation_date).and_yield
    end

    context 'when excluded_geographical_area is nil' do
      before do
        allow(excluded_geo_area).to receive(:excluded_geographical_area).and_return(nil)
        allow(instance).to receive(:geo_area).and_return('United Kingdom (GB)')
      end

      it 'handles nil geographical area gracefully' do
        result = instance.analyze
        expect(result[:change]).to eq('Excluded ')
      end
    end

    context 'when measure has no measure_type' do
      before do
        allow(measure).to receive(:measure_type).and_return(nil)
        allow(instance).to receive_messages(
          measure_type: nil,
          geo_area: 'United Kingdom (GB)',
        )
      end

      it 'handles missing measure type gracefully' do
        result = instance.analyze
        expect(result[:measure_type]).to be_nil
      end
    end

    context 'when geographical_area is nil' do
      before do
        allow(excluded_geo_area).to receive(:geographical_area).and_return(nil)
        allow(instance).to receive(:geo_area).with(nil, []).and_return(nil)
      end

      it 'handles missing geographical area gracefully' do
        result = instance.analyze
        expect(result[:geo_area]).to be_nil
      end
    end
  end

  describe 'business logic validation' do
    context 'with real-world scenario data' do
      let(:real_excluded_date) { Date.parse('2025-03-13') }

      before do
        allow(excluded_geo_area).to receive_messages(
          operation_date: real_excluded_date,
          excluded_geographical_area: 'RU',
          measure_sid: '20260381',
        )
        allow(instance).to receive(:geo_area).and_return('United Kingdom (GB)')
        allow(Measure.operation_klass).to receive_message_chain(:where, :any?).and_return(true)
        allow(TimeMachine).to receive(:at).with(real_excluded_date).and_yield
      end

      it 'captures the excluded geographical area correctly when measures are found' do
        result = instance.analyze

        expect(result).not_to be_nil
        expect(result[:type]).to eq('ExcludedGeographicalArea')
        expect(result[:measure_sid]).to eq('20260381')
        expect(result[:change]).to eq('Excluded RU')
        expect(result[:date_of_effect]).to eq(date)
        expect(result[:description]).to eq('Excluded Geo Area added')
      end
    end

    context 'when no update measures are found (common filtering case)' do
      before do
        allow(Measure.operation_klass).to receive_message_chain(:where, :any?).and_return(false)
      end

      it 'filters out records when no update operations are found' do
        result = instance.analyze
        expect(result).to be_nil
      end
    end
  end
end
