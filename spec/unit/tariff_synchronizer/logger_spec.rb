RSpec.describe TariffSynchronizer::TariffLogger, truncation: true do
  include BankHolidaysHelper

  describe '#rollback_lock_error' do
    before do
      allow(TradeTariffBackend).to receive(
        :with_redis_lock,
      ).and_raise(Redlock::LockError, 'foo')
      allow(Rails.logger).to receive(:warn)
    end

    it 'logs a warn event message' do
      TaricSynchronizer.rollback(Time.zone.today, keep: true)

      expect(Rails.logger).to have_received(:warn).with(include('Failed to acquire Redis lock for rollback'))
    end
  end

  describe '#apply_lock_error' do
    before do
      create(:taric_update, :applied, example_date: Time.zone.yesterday)
      create(:taric_update, :pending, example_date: Time.zone.today)

      allow(TradeTariffBackend).to receive(:with_redis_lock).and_raise(Redlock::LockError, 'foo')
      allow(Rails.logger).to receive(:warn)
    end

    it 'logs warn event message' do
      TaricSynchronizer.apply
      expect(Rails.logger).to have_received(:warn).with(include('Failed to acquire Redis lock for update application'))
    end
  end
end
