RSpec.describe TariffSynchronizer::Logger, truncation: true do
  include BankHolidaysHelper

  before(:all) { WebMock.disable_net_connect! }

  after(:all)  { WebMock.allow_net_connect! }

  before { tariff_synchronizer_logger_listener }

  describe '#missing_updates' do
    let(:not_found_response) { build :response, :not_found }

    before do
      stub_holidays_gem_between_call
      create :taric_update, :missing, issue_date: Date.current.ago(2.days)
      create :taric_update, :missing, issue_date: Date.current.ago(3.days)
      allow(TariffSynchronizer::TariffUpdatesRequester).to receive(:perform)
                                            .and_return(not_found_response)
      TariffSynchronizer::TaricUpdate.sync
    end

    it 'logs a warn event' do
      expect(@logger.logged(:warn).size).to be > 1
      expect(@logger.logged(:warn).to_s).to match(/Missing/)
    end

    it 'sends a warning email' do
      expect(ActionMailer::Base.deliveries).not_to be_empty
      email = ActionMailer::Base.deliveries.last
      expect(email.encoded).to match(/missing/)
    end
  end

  describe '#rollback_lock_error' do
    before do
      expect(TradeTariffBackend).to receive(
        :with_redis_lock,
      ).and_raise(Redlock::LockError, 'foo')

      TariffSynchronizer.rollback(Date.current, true)
    end

    it 'logs a warn event' do
      expect(@logger.logged(:warn).size).to be >= 1
      expect(@logger.logged(:warn).first.to_s).to match(/acquire Redis lock/)
    end
  end

  describe '#apply_lock_error' do
    before do
      create(:taric_update, :applied, example_date: Date.yesterday)
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
