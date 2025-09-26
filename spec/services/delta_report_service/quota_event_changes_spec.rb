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
          quota_definition_sid: 456,
          oid: 2)
  end
  let(:quota_balance_event) do
    build(:quota_balance_event,
          quota_definition_sid: 789,
          oid: 3)
  end
  let(:instance) { described_class.new(quota_definition, date) }

  # rubocop:disable RSpec/MultipleMemoizedHelpers
  describe '.collect' do
    let(:exhaustion_events) { [quota_exhaustion_event] }
    let(:critical_events) { [quota_critical_event] }
    let(:balance_events) { [quota_balance_event] }
    let(:exhaustion_instance) { instance_double(described_class) }
    let(:critical_instance) { instance_double(described_class) }
    let(:balance_instance) { instance_double(described_class) }
    let(:quota_definition_exhausted) { instance_double(QuotaDefinition, quota_definition_sid: quota_exhaustion_event.quota_definition_sid, status: 'Exhausted') }
    let(:quota_definition_critical) { instance_double(QuotaDefinition, quota_definition_sid: quota_critical_event.quota_definition_sid, status: 'Critical') }
    let(:quota_definition_balance) { instance_double(QuotaDefinition, quota_definition_sid: quota_balance_event.quota_definition_sid, status: 'Open') }

    before do
      allow(QuotaExhaustionEvent).to receive(:where).with(operation_date: date).and_return(exhaustion_events)
      allow(QuotaCriticalEvent).to receive(:where).with(operation_date: date).and_return(critical_events)
      allow(QuotaBalanceEvent).to receive(:where).with(operation_date: date).and_return(balance_events)

      allow(QuotaDefinition).to receive(:first) do |args|
        case args[:quota_definition_sid]
        when quota_exhaustion_event.quota_definition_sid
          quota_definition_exhausted
        when quota_critical_event.quota_definition_sid
          quota_definition_critical
        when quota_balance_event.quota_definition_sid
          quota_definition_balance
        end
      end
    end

    context 'when there are quota events for the given date' do
      it 'finds exhaustion, critical and balance events and returns analyzed changes' do
        allow(described_class).to receive(:new).with(quota_definition_exhausted, date).and_return(exhaustion_instance)
        allow(described_class).to receive(:new).with(quota_definition_critical, date).and_return(critical_instance)
        allow(described_class).to receive(:new).with(quota_definition_balance, date).and_return(balance_instance)
        allow(exhaustion_instance).to receive(:analyze)
          .and_return({ type: 'QuotaEvent', description: 'Quota Status: Exhausted' })
        allow(critical_instance).to receive(:analyze)
          .and_return({ type: 'QuotaEvent', description: 'Quota Status: Critical' })
        allow(balance_instance).to receive(:analyze)
          .and_return({ type: 'QuotaEvent', description: 'Quota Status: Open' })

        result = described_class.collect(date)

        expect(QuotaExhaustionEvent).to have_received(:where).with(operation_date: date)
        expect(QuotaCriticalEvent).to have_received(:where).with(operation_date: date)
        expect(QuotaBalanceEvent).to have_received(:where).with(operation_date: date)
        expect(result).to include({ type: 'QuotaEvent', description: 'Quota Status: Exhausted' })
        expect(result).to include({ type: 'QuotaEvent', description: 'Quota Status: Critical' })
        expect(result).to include({ type: 'QuotaEvent', description: 'Quota Status: Open' })
      end
    end

    context 'when analyze returns nil for some events' do
      it 'removes nil values from the result' do
        allow(described_class).to receive(:new).with(quota_definition_exhausted, date).and_return(exhaustion_instance)
        allow(described_class).to receive(:new).with(quota_definition_critical, date).and_return(critical_instance)
        allow(described_class).to receive(:new).with(quota_definition_balance, date).and_return(balance_instance)
        allow(exhaustion_instance).to receive(:analyze)
          .and_return(nil)
        allow(critical_instance).to receive(:analyze)
          .and_return({ type: 'QuotaCriticalEvent', description: 'Quota Status: Critical' })
        allow(balance_instance).to receive(:analyze)
          .and_return(nil)

        result = described_class.collect(date)

        expect(result).to eq([{ type: 'QuotaCriticalEvent', description: 'Quota Status: Critical' }])
      end
    end

    context 'when there are no events for the given date' do
      let(:exhaustion_events) { [] }
      let(:critical_events) { [] }
      let(:balance_events) { [] }

      it 'returns an empty array' do
        result = described_class.collect(date)

        expect(result).to eq([])
      end
    end

    context 'when there are only balance events for the given date' do
      let(:exhaustion_events) { [] }
      let(:critical_events) { [] }

      it 'finds and analyzes balance events correctly' do
        allow(described_class).to receive(:new).with(quota_definition_balance, date).and_return(balance_instance)
        allow(balance_instance).to receive(:analyze)
          .and_return({ type: 'QuotaEvent', description: 'Quota Status: Open' })

        result = described_class.collect(date)

        expect(QuotaBalanceEvent).to have_received(:where).with(operation_date: date)
        expect(result).to eq([{ type: 'QuotaEvent', description: 'Quota Status: Open' }])
      end
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers

  describe '#object_name' do
    it 'returns the correct object name' do
      expect(instance.object_name).to eq('Quota Event')
    end
  end

  describe '#analyze' do
    let(:previous_quota_definition) { instance_double(QuotaDefinition, quota_definition_sid: quota_definition.quota_definition_sid, status: 'Open') }

    before do
      allow(instance).to receive(:date_of_effect).and_return(date)
      allow(quota_definition).to receive(:status).and_return('Exhausted')

      allow(TimeMachine).to receive(:at).and_yield
      allow(QuotaDefinition).to receive(:first).with(quota_definition_sid: quota_definition.quota_definition_sid).and_return(previous_quota_definition)
      allow(previous_quota_definition).to receive(:status).and_return('Open')
    end

    context 'when no errors occur' do
      it 'returns the correct analysis hash' do
        result = instance.analyze

        expect(result).to eq({
          type: 'QuotaEvent',
          quota_definition_sid: quota_definition.quota_definition_sid,
          date_of_effect: date,
          description: 'Quota Status: Exhausted',
          change: 'Quota Exhausted',
        })
      end
    end

    context 'with different status values' do
      it 'includes the status in the description for Critical status' do
        allow(quota_definition).to receive(:status).and_return('Critical')

        result = instance.analyze

        expect(result[:description]).to eq('Quota Status: Critical')
      end

      it 'includes the status in the description for Exhausted status' do
        allow(quota_definition).to receive(:status).and_return('Exhausted')

        result = instance.analyze

        expect(result[:description]).to eq('Quota Status: Exhausted')
      end

      it 'includes the status in the description for Open status' do
        allow(quota_definition).to receive(:status).and_return('Open')
        allow(previous_quota_definition).to receive(:status).and_return('Exhausted')

        result = instance.analyze

        expect(result[:description]).to eq('Quota Status: Open')
      end
    end

    context 'when status transitions should be ignored' do
      it 'returns nil when status has not changed from previous day' do
        allow(quota_definition).to receive(:status).and_return('Critical')
        allow(previous_quota_definition).to receive(:status).and_return('Critical')

        result = instance.analyze

        expect(result).to be_nil
      end

      it 'returns nil when status changes from Critical to Open' do
        allow(quota_definition).to receive(:status).and_return('Open')
        allow(previous_quota_definition).to receive(:status).and_return('Critical')

        result = instance.analyze

        expect(result).to be_nil
      end

      it 'returns result when status changes from Exhausted to Open' do
        allow(quota_definition).to receive(:status).and_return('Open')
        allow(previous_quota_definition).to receive(:status).and_return('Exhausted')

        result = instance.analyze

        expect(result).to be_a(Hash)
        expect(result[:description]).to eq('Quota Status: Open')
      end
    end

    context 'when an error occurs' do
      before do
        allow(Rails.logger).to receive(:error)
        allow(quota_definition).to receive(:status).and_return('Exhausted')

        allow(TimeMachine).to receive(:at).and_yield
        allow(QuotaDefinition).to receive(:first).with(quota_definition_sid: quota_definition.quota_definition_sid).and_return(previous_quota_definition)
        allow(previous_quota_definition).to receive(:status).and_return('Open')
        allow(instance).to receive(:date_of_effect).and_raise(StandardError, 'Test error')
      end

      it 'logs the error and re-raises it' do
        expect { instance.analyze }.to raise_error(StandardError, 'Test error')
        expect(Rails.logger).to have_received(:error).with("Error with Quota Event SID #{quota_definition.quota_definition_sid}")
      end
    end
  end

  describe '#change' do
    before do
      allow(TradeTariffBackend).to receive(:number_formatter).and_return(ActionController::Base.helpers)
    end

    context 'when status is Exhausted' do
      it 'returns "Quota Exhausted"' do
        allow(quota_definition).to receive(:status).and_return('Exhausted')

        result = instance.change

        expect(result).to eq('Quota Exhausted')
      end
    end

    context 'when status is Critical' do
      it 'returns formatted balance with measurement unit' do
        allow(quota_definition).to receive_messages(status: 'Critical', balance: 1234.567, measurement_unit: 'kg')

        result = instance.change

        expect(result).to eq('Balance: 1,234.567 kg')
      end

      it 'formats balance with correct precision and delimiter' do
        allow(quota_definition).to receive_messages(status: 'Critical', balance: 9_876_543.210, measurement_unit: 'tonnes')

        result = instance.change

        expect(result).to eq('Balance: 9,876,543.210 tonnes')
      end

      it 'handles different measurement units' do
        allow(quota_definition).to receive_messages(status: 'Critical', balance: 500.123, measurement_unit: 'litres')

        result = instance.change

        expect(result).to eq('Balance: 500.123 litres')
      end

      it 'handles zero balance' do
        allow(quota_definition).to receive_messages(status: 'Critical', balance: 0.000, measurement_unit: 'kg')

        result = instance.change

        expect(result).to eq('Balance: 0.000 kg')
      end
    end

    context 'when status is Open' do
      it 'returns formatted balance with measurement unit' do
        allow(quota_definition).to receive_messages(status: 'Open', balance: 2345.123, measurement_unit: 'units')

        result = instance.change

        expect(result).to eq('Balance: 2,345.123 units')
      end

      it 'formats balance correctly for Open status' do
        allow(quota_definition).to receive_messages(status: 'Open', balance: 500.000, measurement_unit: 'kg')

        result = instance.change

        expect(result).to eq('Balance: 500.000 kg')
      end
    end
  end

  describe '#date_of_effect' do
    it 'returns the date passed to the constructor' do
      expect(instance.date_of_effect).to eq(date)
    end
  end
end
