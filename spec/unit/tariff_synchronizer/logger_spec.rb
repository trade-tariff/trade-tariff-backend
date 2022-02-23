RSpec.describe TariffSynchronizer::Logger, truncation: true do
  include BankHolidaysHelper

  before(:all) { WebMock.disable_net_connect! }

  after(:all)  { WebMock.allow_net_connect! }

  before { tariff_synchronizer_logger_listener }

  describe '#rollback_lock_error' do
    before do
      expect(TradeTariffBackend).to receive(
        :with_redis_lock,
      ).and_raise(Redlock::LockError, 'foo')

      TariffSynchronizer.rollback(Time.zone.today, keep: true)
    end

    it 'logs a warn event' do
      expect(@logger.logged(:warn).size).to be >= 1
      expect(@logger.logged(:warn).first.to_s).to match(/acquire Redis lock/)
    end
  end

  describe '#apply_lock_error' do
    before do
      create(:taric_update, :applied, example_date: Time.zone.yesterday)
      create(:taric_update, :pending, example_date: Date.today)

      expect(TradeTariffBackend).to receive(:with_redis_lock).and_raise(Redlock::LockError, 'foo')
    end

    it 'logs a warn event' do
      TariffSynchronizer.apply

      expect(@logger.logged(:warn).size).to be >= 1
      expect(@logger.logged(:warn).first.to_s).to match(/acquire Redis lock/)
    end
  end
end
