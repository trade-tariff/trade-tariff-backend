# rubocop:disable RSpec/InstanceVariable
# rubocop:disable RSpec/MultipleExpectations
# rubocop:disable RSpec/AnyInstance
RSpec.describe TaricSynchronizer do
  describe '.download' do
    context 'when sync variables are set' do
      before do
        allow(described_class).to receive(:sync_variables_set?).and_return(true)
      end

      it 'invokes update downloading/syncing on all update types' do
        allow(TariffSynchronizer::TaricUpdate).to receive(:sync).and_return(true)

        described_class.download

        expect(TariffSynchronizer::TaricUpdate).to have_received(:sync)
      end

      it 'logs an info event' do
        expect_any_instance_of(TariffSynchronizer::Logger).to receive(:download)
        allow(TariffSynchronizer::TaricUpdate).to receive(:sync).and_return(true)
        described_class.download
      end

      context 'when patch_broken_taric_downloads is set to true' do
        before do
          allow(TradeTariffBackend).to receive(:patch_broken_taric_downloads?).and_return(true)
        end

        it 'invokes update downloading/syncing on all update types' do
          allow(TariffSynchronizer::TaricUpdate).to receive(:sync_patched).and_return(true)

          described_class.download

          expect(TariffSynchronizer::TaricUpdate).to have_received(:sync_patched)
        end
      end
    end

    context 'when sync variables are not set' do
      it 'does not start sync process' do
        allow(described_class).to receive(:sync_variables_set?).and_return(false)

        allow(TariffSynchronizer::TaricUpdate).to receive(:sync)

        described_class.download

        expect(TariffSynchronizer::TaricUpdate).not_to have_received(:sync)
      end

      it 'logs an error event' do
        expect_any_instance_of(TariffSynchronizer::Logger).to receive(:config_error)

        allow(described_class).to receive(:sync_variables_set?).and_return(false)

        described_class.download
      end
    end

    context 'when a download exception' do
      before do
        allow(described_class).to receive(:sync_variables_set?).and_return(true)
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::Error, 'Foo')
      end

      it 'raises original exception ending the process and logs an error event' do
        tariff_synchronizer_logger_listener
        expect { described_class.download }.to raise_error Faraday::Error
        expect(@logger.logged(:error).size).to eq 1
        expect(@logger.logged(:error).last).to match(/Download failed/)
      end

      it 'sends an email with the exception error' do
        ActionMailer::Base.deliveries.clear
        expect { described_class.download }.to raise_error(Faraday::Error)

        expect(ActionMailer::Base.deliveries).not_to be_empty
        expect(ActionMailer::Base.deliveries.last.encoded).to match(/Backtrace/)
        expect(ActionMailer::Base.deliveries.last.encoded).to match(/Trade Tariff download failure/)
      end
    end
  end

  describe '.apply' do
    let(:applied_update) { create(:taric_update, :applied, example_date: Time.zone.yesterday) }
    let(:pending_update) { create(:taric_update, :pending, example_date: Time.zone.today) }

    context 'when successful' do
      before do
        applied_update
        pending_update

        allow(Sidekiq::Client).to receive(:enqueue)
      end

      it 'all pending updates get applied' do
        allow(TariffSynchronizer::BaseUpdateImporter).to receive(:perform)

        described_class.apply

        expect(TariffSynchronizer::BaseUpdateImporter).to have_received(:perform).with(pending_update)
      end

      it 'logs the info event and send email' do
        expect_any_instance_of(TariffSynchronizer::Logger).to receive(:apply)
        allow(TariffSynchronizer::BaseUpdate).to receive(:pending_or_failed).and_return([])

        allow(TariffSynchronizer::BaseUpdateImporter).to receive(:perform).with(pending_update).and_return(true)

        described_class.apply
      end

      it 'emails stakeholders' do
        allow(TariffSynchronizer::BaseUpdateImporter).to receive(:perform)
        allow(TariffSynchronizer::BaseUpdate).to receive(:pending_or_failed).and_return([])

        described_class.apply

        expect(ActionMailer::Base.deliveries).not_to be_empty
        expect(ActionMailer::Base.deliveries.last.subject).to include('Tariff updates applied')
        expect(ActionMailer::Base.deliveries.last.encoded).to include('No import warnings found.')
      end

      context 'when reindex_all_indexes arg is not set' do
        subject(:apply) { described_class.apply }

        it 'does not kick off the ClearCacheWorker' do
          allow(TariffSynchronizer::BaseUpdateImporter).to receive(:perform)

          apply

          expect(Sidekiq::Client).not_to have_received(:enqueue).with(ClearCacheWorker)
        end
      end

      context 'when reindex_all_indexes arg is false' do
        subject(:apply) { described_class.apply(reindex_all_indexes: false) }

        it 'does not kick off the ClearCacheWorker' do
          allow(TariffSynchronizer::BaseUpdateImporter).to receive(:perform)

          apply

          expect(Sidekiq::Client).not_to have_received(:enqueue).with(ClearCacheWorker)
        end
      end

      context 'when reindex_all_indexes arg is true' do
        subject(:apply) { described_class.apply(reindex_all_indexes: true) }

        it 'kicks off the ClearCacheWorker' do
          allow(TariffSynchronizer::BaseUpdateImporter).to receive(:perform)
          allow(TariffSynchronizer::BaseUpdate).to receive(:pending_or_failed).and_return([])

          apply

          expect(Sidekiq::Client).to have_received(:enqueue).with(ClearCacheWorker)
        end
      end
    end

    context 'when unsuccessful' do
      before do
        applied_update
        pending_update

        allow(TariffSynchronizer::BaseUpdateImporter).to receive(:perform).with(pending_update).and_raise(Sequel::Rollback)
        allow(Sidekiq::Client).to receive(:enqueue)
      end

      it 'after an error next record is not processed' do
        expect { described_class.apply }.to raise_error(Sequel::Rollback)

        expect(Sidekiq::Client).not_to have_received(:enqueue).with(ClearCacheWorker)
      end
    end

    context 'with failed updates present' do
      let(:failed_update) { create(:taric_update, :failed, example_date: Time.zone.yesterday) }

      before do
        failed_update
      end

      it 'does not apply pending updates' do
        allow(TariffSynchronizer::TaricUpdate).to receive(:pending_at)

        expect { described_class.apply }.to raise_error(BaseSynchronizer::FailedUpdatesError)

        expect(TariffSynchronizer::TaricUpdate).not_to have_received(:pending_at)
      end

      it 'logs the error event' do
        expect_any_instance_of(TariffSynchronizer::Logger).to receive(:failed_updates_present)

        expect { described_class.apply }.to raise_error(BaseSynchronizer::FailedUpdatesError)
      end

      it 'sends email with the error' do
        expect { described_class.apply }.to raise_error(BaseSynchronizer::FailedUpdatesError)
      end

      context 'when reindex_all_indexes arg is true' do
        subject(:apply) { described_class.apply(reindex_all_indexes: true) }

        it 'does not kick off the ClearCacheWorker' do
          allow(Sidekiq::Client).to receive(:enqueue)
          allow(TariffSynchronizer::BaseUpdateImporter).to receive(:perform)

          apply
        rescue StandardError
          expect(Sidekiq::Client).not_to have_received(:enqueue).with(ClearCacheWorker)
        end
      end
    end

    context 'when updates sequence is correct' do
      subject(:apply) { described_class.apply }

      before do
        create(:taric_update, :applied, example_date: Time.zone.yesterday, sequence_number: 123)
        create(:taric_update, :pending, example_date: Time.zone.today, sequence_number: 124)

        allow(TradeTariffBackend).to receive(:with_redis_lock)
        allow(TradeTariffBackend).to receive(:uk?).and_return(false)
      end

      it { expect { apply }.not_to raise_error }
    end

    context 'when updates sequence is incorrect' do
      subject(:apply) { described_class.apply }

      before do
        create(:taric_update, :applied, example_date: Time.zone.yesterday, sequence_number: 123)
        create(:taric_update, :pending, example_date: Time.zone.today, sequence_number: 125)

        allow(TradeTariffBackend).to receive(:uk?).and_return(false)
      end

      it 'raises FailedUpdatesError and notifies Slack' do
        allow(SlackNotifierService).to receive(:new).and_call_original

        expect { apply }.to raise_error(BaseSynchronizer::FailedUpdatesError)

        expect(SlackNotifierService).to have_received(:new)
      end
    end
  end
end
# rubocop:enable RSpec/InstanceVariable
# rubocop:enable RSpec/MultipleExpectations
# rubocop:enable RSpec/AnyInstance
