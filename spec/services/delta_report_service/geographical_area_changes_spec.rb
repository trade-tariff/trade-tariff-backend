RSpec.describe DeltaReportService::GeographicalAreaChanges do
  let(:date) { Date.parse('2024-08-11') }

  let(:geographical_area) { build(:geographical_area) }
  let(:instance) { described_class.new(geographical_area, date) }

  before do
    allow(instance).to receive(:get_changes)
  end

  describe '.collect' do
    let(:geographical_area1) { build(:geographical_area, oid: 1, operation_date: date) }
    let(:geographical_area2) { build(:geographical_area, oid: 2, operation_date: date) }
    let(:geographical_areas) { [geographical_area1, geographical_area2] }

    before do
      allow(GeographicalArea).to receive(:where).and_return(geographical_areas)
    end

    it 'finds geographical areas for the given date and returns analyzed changes' do
      instance1 = described_class.new(geographical_area1, date)
      instance2 = described_class.new(geographical_area2, date)

      allow(described_class).to receive(:new).and_return(instance1, instance2)
      allow(instance1).to receive(:analyze).and_return({ type: 'GeographicalArea' })
      allow(instance2).to receive(:analyze).and_return({ type: 'GeographicalArea' })

      result = described_class.collect(date)

      expect(GeographicalArea).to have_received(:where).with(operation_date: date)
      expect(result).to eq([{ type: 'GeographicalArea' }, { type: 'GeographicalArea' }])
    end
  end

  describe '#object_name' do
    it 'returns the correct object name' do
      expect(instance.object_name).to eq('Geo Area')
    end
  end

  describe '#analyze' do
    before do
      allow(instance).to receive_messages(
        no_changes?: false,
        date_of_effect: date,
        description: 'Geo Area updated',
        change: nil,
      )
      allow(instance).to receive(:geo_area).with(geographical_area).and_return('GB: United Kingdom')
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
          type: 'GeographicalArea',
          geographical_area_sid: geographical_area.geographical_area_sid,
          date_of_effect: date,
          description: 'Geo Area updated',
          change: 'GB: United Kingdom',
        })
      end
    end

    context 'when change is not nil' do
      before { allow(instance).to receive(:change).and_return('description updated') }

      it 'uses the change value instead of geo_area' do
        result = instance.analyze
        expect(result[:change]).to eq('description updated')
      end
    end
  end
end
