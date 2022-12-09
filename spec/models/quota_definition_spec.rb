RSpec.describe QuotaDefinition do
  describe '#status' do
    around { |example| TimeMachine.now { example.run } }

    context 'when not in a critical state with no events' do
      subject(:status) { build(:quota_definition, critical_state: 'N').status }

      it { is_expected.to eq 'Open' }
    end

    context 'when in a critical state with no events' do
      subject(:status) { build(:quota_definition, critical_state: 'Y').status }

      it { is_expected.to eq 'Critical' }
    end

    context 'when there are balance events' do
      subject(:status) { create(:quota_definition, :with_quota_balance_events).status }

      it { is_expected.to eq 'Open' }
    end

    context 'when there are critical events' do
      subject(:status) { create(:quota_definition, :with_quota_critical_events).status }

      it { is_expected.to eq 'Critical' }
    end

    context 'when there are exhaustion events' do
      subject(:status) { create(:quota_definition, :with_quota_exhaustion_events).status }

      it { is_expected.to eq 'Exhausted' }
    end

    context 'when there are unsuspension events' do
      subject(:status) { create(:quota_definition, :with_quota_unsuspension_events).status }

      it { is_expected.to eq 'Open' }
    end

    context 'when there are reopening events' do
      subject(:status) { create(:quota_definition, :with_quota_reopening_events).status }

      it { is_expected.to eq 'Open' }
    end

    context 'when there are unblocking events' do
      subject(:status) { create(:quota_definition, :with_quota_unblocking_events).reload.status }

      it { is_expected.to eq 'Open' }
    end

    context 'when there are balance events and an active critical event' do
      subject(:status) { create(:quota_definition, :with_quota_balance_and_active_critical_events).status }

      it { is_expected.to eq 'Critical' }
    end

    context 'when there are balance events and an inactive critical event' do
      subject(:status) { build(:quota_definition, :with_quota_balance_and_inactive_critical_events).status }

      it { is_expected.to eq 'Open' }
    end
  end

  describe '#quota_balance_event_ids' do
    context 'when there are quota balance events' do
      subject(:quota_definition) { create(:quota_definition, :with_quota_balance_events) }

      it 'returns the event ids' do
        expect(quota_definition.quota_balance_event_ids.count).to be_positive
      end
    end

    context 'when there are no quota balance events' do
      subject(:quota_definition) { create(:quota_definition) }

      it 'returns empty event ids' do
        expect(quota_definition.quota_balance_event_ids).to eq([])
      end
    end
  end

  describe '#balance' do
    around do |example|
      TimeMachine.at(Time.zone.today) do
        example.run
      end
    end

    context 'when there are quota balance events' do
      subject(:quota_definition) do
        create(
          :quota_definition,
          :with_quota_balance_events,
          event_new_balance: 6500,
          volume: 6501,
          initial_volume: 6502,
        )
      end

      it 'returns the new balance of the quota balance event' do
        expect(quota_definition.balance).to eq(6500)
      end
    end

    context 'when there are no quota balance events' do
      subject(:quota_definition) do
        create(
          :quota_definition,
          volume: 6501,
          initial_volume: 6502,
        )
      end

      it 'returns initial volume' do
        expect(quota_definition.balance).to eq(6502)
      end
    end
  end

  describe '#incoming_quota_closed_and_transferred_event' do
    subject(:incoming_quota_closed_and_transferred_event) do
      quota_definition.incoming_quota_closed_and_transferred_event
    end

    let(:quota_definition) do
      create(
        :quota_definition,
        :with_incoming_quota_closed_and_transferred_event,
        closing_date: Time.zone.today,
      )
    end

    context 'when the time machine is not set' do
      it { is_expected.to be_present }
    end

    context 'when the time machine is set to be after the closing date' do
      around { |example| TimeMachine.at(Time.zone.today + 1.day, &example) }

      it { is_expected.to be_present }
    end

    context 'when the time machine is set to before the closing date' do
      around { |example| TimeMachine.at(Time.zone.today - 1.day, &example) }

      it { is_expected.not_to be_present }
    end

    context 'when the time machine is set to be on the closing date' do
      around { |example| TimeMachine.at(Time.zone.today, &example) }

      it { is_expected.not_to be_present }
    end
  end
end
