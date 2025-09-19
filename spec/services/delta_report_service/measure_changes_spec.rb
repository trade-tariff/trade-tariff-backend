RSpec.describe DeltaReportService::MeasureChanges do
  let(:date) { Date.parse('2024-08-11') }

  let(:geographical_area) { build(:geographical_area, geographical_area_id: 'GB') }
  let(:measure) do
    build(:measure, goods_nomenclature_item_id: '0101000000', validity_start_date: date)
  end
  let(:instance) { described_class.new(measure, date) }

  before do
    allow(measure).to receive(:geographical_area).and_return(geographical_area)
    allow(instance).to receive(:get_changes)
  end

  describe '.collect' do
    let(:measure_operation1) { instance_double(Measure::Operation, oid: 1, record_from_oplog: measure) }
    let(:measure_operation2) { instance_double(Measure::Operation, oid: 2, record_from_oplog: measure) }
    let(:measure_operations) { [measure_operation1, measure_operation2] }

    before do
      allow(Measure::Operation).to receive(:where).with(operation_date: date).and_return(measure_operations)
    end

    it 'finds measure operations for the given date and returns analyzed changes' do
      # Mock the map behavior which creates instances and calls analyze
      allow(measure_operations).to receive_messages(
        map: [{ type: 'Measure' }, { type: 'Measure' }],
        compact: [{ type: 'Measure' }, { type: 'Measure' }],
      )

      result = described_class.collect(date)

      expect(Measure::Operation).to have_received(:where).with(operation_date: date)
      expect(result).to eq([{ type: 'Measure' }, { type: 'Measure' }])
    end
  end

  describe '#object_name' do
    it 'returns the correct object name' do
      expect(instance.object_name).to eq('Measure')
    end
  end

  describe '#excluded_columns' do
    it 'includes measure-specific excluded columns' do
      expected = instance.send(:excluded_columns)
      expect(expected).to include(:measure_generating_regulation_id)
      expect(expected).to include(:justification_regulation_role)
      expect(expected).to include(:justification_regulation_id)
    end

    it 'includes base excluded columns' do
      base_excluded = %i[oid operation operation_date created_at updated_at filename]
      expected = instance.send(:excluded_columns)

      base_excluded.each do |column|
        expect(expected).to include(column)
      end
    end
  end

  describe '#analyze' do
    before do
      allow(instance).to receive_messages(
        no_changes?: false,
        description: 'Measure updated',
        date_of_effect: date,
        change: nil,
      )
      allow(instance).to receive(:measure_type).with(measure).and_return('Third country duty')
      allow(instance).to receive(:import_export).with(measure).and_return('Import')
      allow(instance).to receive(:geo_area).with(geographical_area, []).and_return('United Kingdom (GB)')
      allow(instance).to receive(:additional_code).with(nil).and_return('A123: Special code')
      allow(instance).to receive(:duty_expression).with(measure).and_return('10%')
    end

    context 'when there are no changes' do
      before { allow(instance).to receive(:no_changes?).and_return(true) }

      it 'returns nil' do
        expect(instance.analyze).to be_nil
      end
    end

    context 'when changes should be included' do
      it 'returns the correct analysis hash' do
        result = instance.analyze

        expect(result).to eq({
          type: 'Measure',
          goods_nomenclature_item_id: '0101000000',
          validity_start_date: date,
          validity_end_date: nil,
          measure_type: 'Third country duty',
          import_export: 'Import',
          geo_area: 'United Kingdom (GB)',
          description: 'Measure updated',
          date_of_effect: date,
          change: 'Third country duty',
        })
      end
    end

    context 'when change is not nil' do
      before { allow(instance).to receive(:change).and_return('duty rate changed') }

      it 'uses the change value instead of measure_type' do
        result = instance.analyze
        expect(result[:change]).to eq('duty rate changed')
      end
    end
  end
end
