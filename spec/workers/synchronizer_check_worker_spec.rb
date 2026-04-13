RSpec.describe SynchronizerCheckWorker, type: :worker do
  describe '#perform' do
    subject(:perform) { described_class.new.perform }

    before { allow(NewRelic::Agent).to receive(:record_custom_event) }

    context 'when there are no applied updates' do
      before { perform }

      it 'records the sentinel age event' do
        expect(NewRelic::Agent).to have_received(:record_custom_event)
          .with('TariffSyncAge', service: 'uk', age_minutes: SynchronizerCheckWorker::NO_SYNC_SENTINEL_MINUTES, expected_stale: false)
      end
    end

    context 'when the most recent applied update is recent' do
      before do
        create :base_update, :applied, applied_at: 2.hours.ago
        perform
      end

      it 'records an age event close to 120 minutes' do
        expect(NewRelic::Agent).to have_received(:record_custom_event)
          .with('TariffSyncAge', service: 'uk', age_minutes: be_within(2).of(120), expected_stale: false)
      end
    end

    context 'when the most recent applied update is stale' do
      before do
        create :base_update, :applied, applied_at: 25.hours.ago
        perform
      end

      it 'records an age event over 24 hours' do
        expect(NewRelic::Agent).to have_received(:record_custom_event)
          .with('TariffSyncAge', service: 'uk', age_minutes: be > 1440, expected_stale: false)
      end
    end

    context 'when the XI service is running' do
      before { allow(TradeTariffBackend).to receive(:service).and_return('xi') }

      context 'on a day with no TARIC updates (Sunday, Monday, Tuesday)' do
        before do
          create :base_update, :applied, applied_at: 2.days.ago
          travel_to Time.zone.now.next_occurring(:monday)
          perform
        end

        it 'records the event as expected_stale' do
          expect(NewRelic::Agent).to have_received(:record_custom_event)
            .with('TariffSyncAge', service: 'xi', age_minutes: be > 1440, expected_stale: true)
        end
      end

      context 'on a day with TARIC updates (Wednesday–Saturday)' do
        before do
          create :base_update, :applied, applied_at: 2.hours.ago
          travel_to Time.zone.now.next_occurring(:wednesday)
          perform
        end

        it 'records the event as not expected_stale' do
          expect(NewRelic::Agent).to have_received(:record_custom_event)
            .with('TariffSyncAge', service: 'xi', age_minutes: be_within(2).of(120), expected_stale: false)
        end
      end
    end
  end
end
