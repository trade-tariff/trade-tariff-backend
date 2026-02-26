RSpec.describe TariffSynchronizer::TariffLogger, :truncation do
  include BankHolidaysHelper

  before do
    allow(TradeTariffBackend).to receive(:service).and_return('xi')
  end

  describe '#rollback_lock_error' do
    before do
      allow(TradeTariffBackend).to receive(
        :with_redis_lock,
      ).and_raise(Redlock::LockError, 'foo')
      allow(TariffSynchronizer::Instrumentation).to receive(:lock_failed)
    end

    it 'emits a lock_failed instrumentation event' do
      TaricSynchronizer.rollback(Time.zone.today, keep: true)

      expect(TariffSynchronizer::Instrumentation).to have_received(:lock_failed).with(phase: 'rollback')
    end
  end

  describe '#apply_lock_error' do
    before do
      create(:taric_update, :applied, example_date: Time.zone.yesterday)
      create(:taric_update, :pending, example_date: Time.zone.today)

      allow(TradeTariffBackend).to receive(:with_redis_lock).and_raise(Redlock::LockError, 'foo')
      allow(TariffSynchronizer::Instrumentation).to receive(:lock_failed)
    end

    it 'emits a lock_failed instrumentation event' do
      TaricSynchronizer.apply
      expect(TariffSynchronizer::Instrumentation).to have_received(:lock_failed).with(phase: 'apply')
    end
  end
end
