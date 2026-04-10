RSpec.describe SynchronizerCheckWorker, type: :worker do
  describe '#perform' do
    subject(:perform) { described_class.new.perform }

    before { allow(NewRelic::Agent).to receive(:record_custom_event) }

    context 'when there are no applied updates' do
      before { perform }

      it 'records the sentinel age event' do
        expect(NewRelic::Agent).to have_received(:record_custom_event)
          .with('TariffSyncAge', service: 'uk', age_minutes: SynchronizerCheckWorker::NO_SYNC_SENTINEL_MINUTES)
      end
    end

    context 'when the most recent applied update is recent' do
      before do
        create :base_update, :applied, applied_at: 2.hours.ago
        perform
      end

      it 'records an age event close to 120 minutes' do
        expect(NewRelic::Agent).to have_received(:record_custom_event)
          .with('TariffSyncAge', service: 'uk', age_minutes: be_within(2).of(120))
      end
    end

    context 'when the most recent applied update is stale' do
      before do
        create :base_update, :applied, applied_at: 25.hours.ago
        perform
      end

      it 'records an age event over 24 hours' do
        expect(NewRelic::Agent).to have_received(:record_custom_event)
          .with('TariffSyncAge', service: 'uk', age_minutes: be > 1440)
      end
    end
  end
end
