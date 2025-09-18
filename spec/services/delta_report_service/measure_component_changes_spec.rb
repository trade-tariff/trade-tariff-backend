RSpec.describe DeltaReportService::MeasureComponentChanges do
  let(:date) { Date.parse('2024-08-11') }

  let(:geographical_area) { build(:geographical_area) }
  let(:measure) { build(:measure, operation_date: date - 1.day) }
  let(:measure_component) { build(:measure_component) }
  let(:instance) { described_class.new(measure_component, date) }

  before do
    allow(measure_component).to receive_messages(
      measure: measure,
      measure_sid: '12345',
    )
    allow(measure).to receive(:geographical_area).and_return(geographical_area)
    allow(instance).to receive(:get_changes)
  end

  describe '.collect' do
    let(:measure_component1) { build(:measure_component, oid: 1, operation_date: date) }
    let(:measure_component2) { build(:measure_component, oid: 2, operation_date: date) }
    let(:measure_components) { [measure_component1, measure_component2] }

    before do
      allow(MeasureComponent).to receive(:where).and_return(measure_components)
    end

    it 'finds measure components for the given date and returns analyzed changes' do
      instance1 = described_class.new(measure_component1, date)
      instance2 = described_class.new(measure_component2, date)

      allow(described_class).to receive(:new).and_return(instance1, instance2)
      allow(instance1).to receive(:analyze).and_return({ type: 'MeasureComponent' })
      allow(instance2).to receive(:analyze).and_return({ type: 'MeasureComponent' })

      result = described_class.collect(date)

      expect(MeasureComponent).to have_received(:where).with(operation_date: date)
      expect(result).to eq([{ type: 'MeasureComponent' }, { type: 'MeasureComponent' }])
    end
  end

  describe '#object_name' do
    context 'when tariff duty' do
      it 'returns the correct object name' do
        expect(instance.object_name).to eq('Duty Expression')
      end
    end

    context 'when supplementary unit' do
      it 'returns the correct object name' do
        allow(measure).to receive(:supplementary?).and_return(true)
        expect(instance.object_name).to eq('Supplementary Unit')
      end
    end
  end

  describe '#analyze' do
    before do
      allow(instance).to receive_messages(
        no_changes?: false,
        description: 'Measure Component updated',
        date_of_effect: date,
        change: nil,
      )
      allow(instance).to receive(:measure_type).with(measure).and_return('103: Third country duty')
      allow(instance).to receive(:import_export).with(measure).and_return('Import')
      allow(instance).to receive(:geo_area).with(geographical_area, []).and_return('United Kingdom (GB)')
      allow(instance).to receive(:additional_code).with(nil).and_return(nil)
      allow(instance).to receive(:duty_expression).with(measure).and_return('5%')
      allow(measure).to receive(:additional_code).and_return(nil)
      # By default, don't filter out records (no matching operations found)
      allow(Measure::Operation).to receive_message_chain(:where, :any?).and_return(false)
    end

    context 'when there are no changes' do
      before { allow(instance).to receive(:no_changes?).and_return(true) }

      it 'returns nil' do
        expect(instance.analyze).to be_nil
      end
    end

    context 'when record operation is create and measure operation_date equals record operation_date' do
      let(:measure_component_create) { build(:measure_component, operation: :create, operation_date: date) }
      let(:measure_create) { build(:measure, operation_date: date) }
      let(:instance_create) { described_class.new(measure_component_create, date) }

      before do
        allow(measure_component_create).to receive(:measure).and_return(measure_create)
        allow(instance_create).to receive(:get_changes)
        allow(instance_create).to receive(:no_changes?).and_return(false)
        # Mock the Measure::Operation query to return true (measure found on same date)
        allow(Measure::Operation).to receive_message_chain(:where, :any?).and_return(true)
      end

      it 'returns nil' do
        expect(instance_create.analyze).to be_nil
      end
    end

    context 'when changes should be included' do
      it 'returns the correct analysis hash' do
        result = instance.analyze

        expect(result).to eq({
          type: 'MeasureComponent',
          measure_sid: '12345',
          measure_type: '103: Third country duty',
          import_export: 'Import',
          geo_area: 'United Kingdom (GB)',
          description: 'Measure Component updated',
          date_of_effect: date,
          change: '5%',
        })
      end
    end

    context 'when change is not nil' do
      before { allow(instance).to receive(:change).and_return('component value changed') }

      it 'uses the change value instead of duty_expression' do
        result = instance.analyze
        expect(result[:change]).to eq('component value changed')
      end
    end
  end

  describe '#date_of_effect' do
    it 'returns the date parameter' do
      expect(instance.date_of_effect).to eq(date)
    end
  end
end
