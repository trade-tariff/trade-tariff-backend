RSpec.describe QuotaDefinition do
  describe '#status' do
    before do
      TradeTariffRequest.time_machine_now = Time.current
    end

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

    context 'when there is a valid suspension period it doenst overide the quota exausted status' do
      subject(:status) { create(:quota_definition, :with_quota_exhaustion_events, :with_quota_suspension_period).reload.status }

      it { is_expected.to eq 'Exhausted' }
    end

    context 'when there is a valid suspension period' do
      subject(:status) { create(:quota_definition, :with_quota_suspension_period).reload.status }

      it { is_expected.to eq 'Suspended' }
    end

    context 'when there is a expired suspension period' do
      subject(:status) { create(:quota_definition, :with_expired_quota_suspension_period).reload.status }

      it { is_expected.to eq 'Open' }
    end

    context 'when there is a valid blocking period' do
      subject(:status) { create(:quota_definition, :with_quota_blocking_period).reload.status }

      it { is_expected.to eq 'Blocked' }
    end

    context 'when there is a expired blocking period' do
      subject(:status) { create(:quota_definition, :with_expired_quota_blocking_period).reload.status }

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

  describe '#quota_order_number_origin_ids' do
    let(:quota_order_number) { create :quota_order_number }
    let(:quota_definition) do
      create(:quota_definition, :with_quota_balance_events,
             quota_order_number_sid: quota_order_number.quota_order_number_sid,
             quota_order_number_id: quota_order_number.quota_order_number_id)
    end

    context 'when there are quota order number origins' do
      before do
        create(:quota_order_number_origin, :with_geographical_area,
               quota_order_number_sid: quota_order_number.quota_order_number_sid)
      end

      it 'returns the ids' do
        expect(quota_definition.quota_order_number_origin_ids.count).to be_positive
      end
    end

    context 'when there are no quota order number origins' do
      it 'returns empty ids' do
        expect(quota_definition.quota_order_number_origin_ids).to eq([])
      end
    end
  end

  describe '#quota_unsuspension_event_ids' do
    context 'when there are quota unsuspension events' do
      let(:quota_definition) { create(:quota_definition, :with_quota_unsuspension_events) }

      it 'returns the ids' do
        expect(quota_definition.quota_unsuspension_event_ids.count).to be_positive
      end
    end

    context 'when there are no quota unsuspension events' do
      let(:quota_definition) { create(:quota_definition) }

      it 'returns empty ids' do
        expect(quota_definition.quota_unsuspension_event_ids).to eq([])
      end
    end
  end

  describe '#quota_reopening_event_ids' do
    context 'when there are quota reopening events' do
      let(:quota_definition) { create(:quota_definition, :with_quota_reopening_events) }

      it 'returns the ids' do
        expect(quota_definition.quota_reopening_event_ids.count).to be_positive
      end
    end

    context 'when there are no quota reopening events' do
      let(:quota_definition) { create(:quota_definition) }

      it 'returns empty ids' do
        expect(quota_definition.quota_reopening_event_ids).to eq([])
      end
    end
  end

  describe '#quota_unblocking_event_ids' do
    context 'when there are quota unblocking events' do
      let(:quota_definition) { create(:quota_definition, :with_quota_unblocking_events) }

      it 'returns the ids' do
        expect(quota_definition.quota_unblocking_event_ids.count).to be_positive
      end
    end

    context 'when there are no quota unblocking events' do
      let(:quota_definition) { create(:quota_definition) }

      it 'returns empty ids' do
        expect(quota_definition.quota_unblocking_event_ids).to eq([])
      end
    end
  end

  describe '#quota_exhaustion_event_ids' do
    context 'when there are quota exhaustion events' do
      let(:quota_definition) { create(:quota_definition, :with_quota_exhaustion_events) }

      it 'returns the ids' do
        expect(quota_definition.quota_exhaustion_event_ids.count).to be_positive
      end
    end

    context 'when there are no quota exhaustion events' do
      let(:quota_definition) { create(:quota_definition) }

      it 'returns empty ids' do
        expect(quota_definition.quota_exhaustion_event_ids).to eq([])
      end
    end
  end

  describe '#quota_critical_event_ids' do
    context 'when there are quota critical events' do
      let(:quota_definition) { create(:quota_definition, :with_quota_critical_events) }

      it 'returns the ids' do
        TradeTariffRequest.time_machine_now = Time.current
        expect(quota_definition.quota_critical_event_ids.count).to be_positive
      end
    end

    context 'when there are no quota exhaustion events' do
      let(:quota_definition) { create(:quota_definition) }

      it 'returns empty ids' do
        expect(quota_definition.quota_critical_event_ids).to eq([])
      end
    end
  end

  describe '#quota_type' do
    context 'when quota_order_number_id contains 4 as third digit' do
      subject(:quota_definition) { create(:quota_definition, :licensed) }

      it 'returns Licensed' do
        expect(quota_definition.quota_type).to eq('Licensed')
      end
    end

    context 'when quota_order_number_id does not contain 4 as third digit' do
      subject(:quota_definition) { create(:quota_definition, :first_come_first_served) }

      it 'returns First Come First Served' do
        expect(quota_definition.quota_type).to eq('First Come First Served')
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
      around { |example| TimeMachine.no_time_machine { example.run } }

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

  describe '#shows_balance_transfers?' do
    subject(:quota_definition) { build(:quota_definition, validity_start_date:) }

    context 'when the validity start date is before the hmrc date' do
      let(:validity_start_date) { Date.parse('2022-06-30').iso8601 }

      it { is_expected.not_to be_shows_balance_transfers }
    end

    context 'when the validity start date is on the hmrc date' do
      let(:validity_start_date) { Date.parse('2022-07-01').iso8601 }

      it { is_expected.to be_shows_balance_transfers }
    end

    context 'when the validity start date is after the hmrc date' do
      let(:validity_start_date) { Date.parse('2022-07-02').iso8601 }

      it { is_expected.to be_shows_balance_transfers }
    end
  end

  describe '.excluding_licensed_quotas' do
    subject(:dataset) { described_class.excluding_licensed_quotas }

    before do
      create(:quota_definition, quota_order_number_id: '094001') # licensed and excluded
      create(:quota_definition, quota_order_number_id: '096001') # non-licensed not excluded
    end

    it { expect(dataset.pluck(:quota_order_number_id)).to eq %w[096001] }
  end
end
