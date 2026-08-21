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

  describe '.apply' do
    let(:update_names) { %w[2024-01-01_xi_taric_update.xml] }
    let(:mail_double) { instance_double(ActionMailer::MessageDelivery, deliver_now: nil) }

    before do
      allow(TariffSynchronizer::Mailer).to receive(:applied).and_return(mail_double)
      allow(TaricSynchronizer).to receive(:ignore_presence_errors).and_return(false)
      allow(TariffSynchronizer::TariffUpdatePresenceError).to receive(:where).and_return([])
    end

    context 'when there are no import warnings and no presence errors' do
      it 'does not deliver the applied email' do
        described_class.apply(update_names, [])
        expect(TariffSynchronizer::Mailer).not_to have_received(:applied)
      end
    end

    context 'when there are import warnings' do
      let(:import_warnings) { [{ message: 'Unexpected element', xml_node: '<foo/>' }] }

      it 'delivers the applied email' do
        described_class.apply(update_names, import_warnings)
        expect(TariffSynchronizer::Mailer).to have_received(:applied).with(update_names, import_warnings)
      end
    end

    context 'when presence errors exist and ignore_presence_errors is enabled' do
      before do
        allow(TaricSynchronizer).to receive(:ignore_presence_errors).and_return(true)
        allow(TariffSynchronizer::TariffUpdatePresenceError).to receive(:where)
          .with(tariff_update_filename: update_names)
          .and_return([instance_double(TariffSynchronizer::TariffUpdatePresenceError)])
      end

      it 'delivers the applied email' do
        described_class.apply(update_names, [])
        expect(TariffSynchronizer::Mailer).to have_received(:applied).with(update_names, [])
      end
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
