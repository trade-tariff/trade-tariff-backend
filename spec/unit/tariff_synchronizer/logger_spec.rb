RSpec.describe TariffSynchronizer::TariffLogger, truncation: true do
  include BankHolidaysHelper

  describe '#rollback_lock_error' do
    before do
      expect(TradeTariffBackend).to receive(
        :with_redis_lock,
      ).and_raise(Redlock::LockError, 'foo')
    end

    it 'logs a warn event' do
      expect(Rails.logger.warn.size).to be >= 1
      expect(Rails.logger).to receive(:warn).with(include('Failed to acquire Redis lock for rollback'))

      TaricSynchronizer.rollback(Time.zone.today, keep: true)
    end
  end

  describe '#apply_lock_error' do
    before do
      create(:taric_update, :applied, example_date: Time.zone.yesterday)
      create(:taric_update, :pending, example_date: Time.zone.today)

      expect(TradeTariffBackend).to receive(:with_redis_lock).and_raise(Redlock::LockError, 'foo')
    end

    it 'logs a warn event' do
      expect(Rails.logger.warn.size).to be >= 1
      expect(Rails.logger).to receive(:warn).with(include('Failed to acquire Redis lock for update application'))

      TaricSynchronizer.apply
    end
  end
end
