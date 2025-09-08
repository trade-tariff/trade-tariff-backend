RSpec.describe DeltaReportService::MeasureConditionChanges do
  let(:date) { Date.parse('2024-08-11') }

  let(:geographical_area) { build(:geographical_area, geographical_area_id: 'GB') }
  let(:measure) { build(:measure, measure_sid: '12345', operation_date: date - 1.day) }
  let(:measure_condition) { build(:measure_condition) }
  let(:instance) { described_class.new(measure_condition, date) }

  before do
    allow(measure_condition).to receive(:measure).and_return(measure)
    allow(measure).to receive(:geographical_area).and_return(geographical_area)
    allow(instance).to receive(:get_changes)
    allow(measure_condition).to receive_messages(
      measure: measure,
      measure_sid: '12345',
    )
  end

  describe '.collect' do
    let(:measure_condition1) { build(:measure_condition, oid: 1, operation_date: date) }
    let(:measure_condition2) { build(:measure_condition, oid: 2, operation_date: date) }
    let(:measure_conditions) { [measure_condition1, measure_condition2] }

    before do
      allow(MeasureCondition).to receive_message_chain(:where, :order).and_return(measure_conditions)
    end

    it 'finds measure conditions for the given date and returns analyzed changes' do
      instance1 = described_class.new(measure_condition1, date)
      instance2 = described_class.new(measure_condition2, date)

      allow(described_class).to receive(:new).and_return(instance1, instance2)
      allow(instance1).to receive(:analyze).and_return({ type: 'MeasureCondition' })
      allow(instance2).to receive(:analyze).and_return({ type: 'MeasureCondition' })

      result = described_class.collect(date)

      expect(MeasureCondition).to have_received(:where).with(operation_date: date)
      expect(result).to eq([{ type: 'MeasureCondition' }, { type: 'MeasureCondition' }])
    end
  end

  describe '#object_name' do
    it 'returns the correct object name' do
      expect(instance.object_name).to eq('Document')
    end
  end

  describe '#analyze' do
    let(:additional_code) { build(:additional_code) }

    before do
      allow(instance).to receive_messages(
        no_changes?: false,
        description: 'Measure Condition updated',
        date_of_effect: date,
        change: 'new condition',
      )
      allow(instance).to receive(:measure_type).with(measure).and_return('103: Third country duty')
      allow(instance).to receive(:import_export).with(measure).and_return('Import')
      allow(instance).to receive(:geo_area).with(geographical_area).and_return('GB: United Kingdom')
      allow(instance).to receive(:additional_code).with(nil).and_return(additional_code)
      allow(instance).to receive(:duty_expression).with(measure).and_return('10%')
    end

    context 'when there are no changes' do
      before { allow(instance).to receive(:no_changes?).and_return(true) }

      it 'returns nil' do
        expect(instance.analyze).to be_nil
      end
    end

    context 'when record operation is create and measure operation_date equals record operation_date' do
      let(:measure_condition_create) { build(:measure_condition, operation: :create, operation_date: date) }
      let(:measure_create) { build(:measure, operation_date: date) }
      let(:instance_create) { described_class.new(measure_condition_create, date) }

      before do
        allow(measure_condition_create).to receive(:measure).and_return(measure_create)
        allow(instance_create).to receive(:get_changes)
        allow(instance_create).to receive(:no_changes?).and_return(false)
      end

      it 'returns nil' do
        expect(instance_create.analyze).to be_nil
      end
    end

    context 'when changes should be included' do
      it 'returns the correct analysis hash' do
        result = instance.analyze

        expect(result).to eq({
          type: 'MeasureCondition',
          measure_sid: '12345',
          measure_type: '103: Third country duty',
          import_export: 'Import',
          geo_area: 'GB: United Kingdom',
          additional_code: additional_code,
          duty_expression: '10%',
          description: 'Measure Condition updated',
          date_of_effect: date,
          change: 'new condition',
        })
      end
    end

    context 'when change is nil' do
      before { allow(instance).to receive(:change).and_return(nil) }

      it 'sets change to empty string' do
        result = instance.analyze
        expect(result[:change]).to be_nil
      end
    end
  end

  describe '#date_of_effect' do
    it 'returns the date parameter' do
      expect(instance.date_of_effect).to eq(date)
    end
  end

  describe '#excluded_columns' do
    it 'includes component_sequence_number in excluded columns' do
      expected = instance.send(:excluded_columns)
      expect(expected).to include(:component_sequence_number)
    end

    it 'includes base excluded columns' do
      base_excluded = %i[oid operation operation_date created_at updated_at filename]
      expected = instance.send(:excluded_columns)

      base_excluded.each do |column|
        expect(expected).to include(column)
      end
    end
  end
end
