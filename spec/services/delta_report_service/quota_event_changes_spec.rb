RSpec.describe DeltaReportService::QuotaEventChanges do
  let(:date) { Date.parse('2024-08-11') }
  let(:quota_definition) { build(:quota_definition, quota_definition_sid: 123) }
  let(:quota_exhaustion_event) do
    build(:quota_exhaustion_event,
          quota_definition_sid: quota_definition.quota_definition_sid,
          oid: 1)
  end
  let(:quota_critical_event) do
    build(:quota_critical_event,
          quota_definition_sid: quota_definition.quota_definition_sid,
          oid: 2)
  end
  let(:instance) { described_class.new(quota_exhaustion_event, date) }

  before do
    allow(instance).to receive(:get_changes)
  end

  describe '.collect' do
    let(:exhaustion_events) { [quota_exhaustion_event] }
    let(:critical_events) { [quota_critical_event] }
    let(:exhaustion_instance) { instance_double(described_class) }
    let(:critical_instance) { instance_double(described_class) }

    before do
      allow(QuotaExhaustionEvent).to receive(:where).with(operation_date: date).and_return(exhaustion_events)
      allow(QuotaCriticalEvent).to receive(:where).with(operation_date: date).and_return(critical_events)
    end

    context 'when there are quota events for the given date' do
      it 'finds exhaustion and critical events and returns analyzed changes' do
        allow(described_class).to receive(:new).with(quota_exhaustion_event, date).and_return(exhaustion_instance)
        allow(described_class).to receive(:new).with(quota_critical_event, date).and_return(critical_instance)
        allow(exhaustion_instance).to receive(:analyze)
          .with('Exhausted').and_return({ type: 'QuotaEvent', description: 'Quota Status: Exhausted' })
        allow(critical_instance).to receive(:analyze)
          .with('Critical').and_return({ type: 'QuotaEvent', description: 'Quota Status: Critical' })

        result = described_class.collect(date)

        expect(QuotaExhaustionEvent).to have_received(:where).with(operation_date: date)
        expect(QuotaCriticalEvent).to have_received(:where).with(operation_date: date)
        expect(result).to include({ type: 'QuotaEvent', description: 'Quota Status: Exhausted' })
        expect(result).to include({ type: 'QuotaEvent', description: 'Quota Status: Critical' })
      end
    end

    context 'when analyze returns nil for some events' do
      it 'removes nil values from the result' do
        allow(described_class).to receive(:new).with(quota_exhaustion_event, date).and_return(exhaustion_instance)
        allow(described_class).to receive(:new).with(quota_critical_event, date).and_return(critical_instance)
        allow(exhaustion_instance).to receive(:analyze)
          .with('Exhausted').and_return(nil)
        allow(critical_instance).to receive(:analyze)
          .with('Critical').and_return({ type: 'QuotaEvent', description: 'Quota Status: Critical' })

        result = described_class.collect(date)

        expect(result).to eq([{ type: 'QuotaEvent', description: 'Quota Status: Critical' }])
      end
    end

    context 'when there are no events for the given date' do
      let(:exhaustion_events) { [] }
      let(:critical_events) { [] }

      it 'returns an empty array' do
        result = described_class.collect(date)

        expect(result).to eq([])
      end
    end
  end

  describe '#object_name' do
    it 'returns the correct object name' do
      expect(instance.object_name).to eq('Quota Event')
    end
  end

  describe '#analyze' do
    let(:status) { 'Exhausted' }

    before do
      allow(instance).to receive(:date_of_effect).and_return(date)
    end

    context 'when no errors occur' do
      it 'returns the correct analysis hash' do
        result = instance.analyze(status)

        expect(result).to eq({
          type: 'QuotaEvent',
          quota_definition_sid: quota_exhaustion_event.quota_definition_sid,
          date_of_effect: date,
          description: "Quota Status: #{status}",
        })
      end
    end

    context 'with different status values' do
      it 'includes the status in the description for Critical status' do
        result = instance.analyze('Critical')

        expect(result[:description]).to eq('Quota Status: Critical')
      end

      it 'includes the status in the description for Exhausted status' do
        result = instance.analyze('Exhausted')

        expect(result[:description]).to eq('Quota Status: Exhausted')
      end
    end

    context 'when an error occurs' do
      before do
        allow(instance).to receive(:date_of_effect).and_raise(StandardError, 'Test error')
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the error and re-raises it' do
        expect { instance.analyze(status) }.to raise_error(StandardError, 'Test error')
        expect(Rails.logger).to have_received(:error).with("Error with Quota Event OID #{quota_exhaustion_event.oid}")
      end
    end
  end

  describe '#date_of_effect' do
    it 'returns the date passed to the constructor' do
      expect(instance.date_of_effect).to eq(date)
    end
  end
end
