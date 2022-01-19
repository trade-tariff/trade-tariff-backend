# rubocop:disable RSpec/InstanceVariable
# rubocop:disable RSpec/MultipleExpectations
# rubocop:disable RSpec/AnyInstance
RSpec.describe TariffSynchronizer, truncation: true do
  describe '.initial_update_date_for' do
    # helper method where update type is a param
    it 'returns initial update date for specific update type taric' do
      expect(described_class.initial_update_date_for(:taric)).to eq(described_class.taric_initial_update_date)
      expect(described_class.initial_update_date_for(:cds)).to eq(described_class.cds_initial_update_date)
      expect { described_class.initial_update_date_for(:non_existent) }.to raise_error(NoMethodError)
    end
  end

  describe '.download' do
    context 'when sync variables are set' do
      before do
        allow(described_class).to receive(:sync_variables_set?).and_return(true)
      end

      it 'invokes update downloading/syncing on all update types' do
        allow(described_class::TaricUpdate).to receive(:sync).and_return(true)

        described_class.download

        expect(described_class::TaricUpdate).to have_received(:sync)
      end

      it 'logs an info event' do
        expect_any_instance_of(TariffSynchronizer::Logger).to receive(:download)
        allow(described_class::TaricUpdate).to receive(:sync).and_return(true)
        described_class.download
      end
    end

    context 'when sync variables are not set' do
      it 'does not start sync process' do
        allow(described_class).to receive(:sync_variables_set?).and_return(false)

        allow(described_class::TaricUpdate).to receive(:sync)

        described_class.download

        expect(described_class::TaricUpdate).not_to have_received(:sync)
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
        allow_any_instance_of(Curl::Easy).to receive(:perform)
                                         .and_raise(Curl::Err::HostResolutionError)
      end

      it 'raises original exception ending the process and logs an error event' do
        tariff_synchronizer_logger_listener
        expect { described_class.download }.to raise_error Curl::Err::HostResolutionError
        expect(@logger.logged(:error).size).to eq 1
        expect(@logger.logged(:error).last).to match(/Download failed/)
      end

      it 'sends an email with the exception error' do
        ActionMailer::Base.deliveries.clear
        expect { described_class.download }.to raise_error(Curl::Err::HostResolutionError)

        expect(ActionMailer::Base.deliveries).not_to be_empty
        expect(ActionMailer::Base.deliveries.last.encoded).to match(/Backtrace/)
        expect(ActionMailer::Base.deliveries.last.encoded).to match(/Curl::Err::HostResolutionError/)
      end
    end
  end

  describe '.apply' do
    let(:applied_update) { create(:taric_update, :applied, example_date: Date.yesterday) }
    let(:pending_update) { create(:taric_update, :pending, example_date: Date.today) }

    context 'when successful' do
      before do
        applied_update
        pending_update

        allow(Sidekiq::Client).to receive(:enqueue)
      end

      it 'all pending updates get applied' do
        allow(described_class::BaseUpdateImporter).to receive(:perform)

        described_class.apply

        expect(described_class::BaseUpdateImporter).to have_received(:perform).with(pending_update)
      end

      it 'logs the info event and send email' do
        expect_any_instance_of(TariffSynchronizer::Logger).to receive(:apply)
        allow(described_class::BaseUpdate).to receive(:pending_or_failed).and_return([])

        allow(described_class::BaseUpdateImporter).to receive(:perform).with(pending_update).and_return(true)

        described_class.apply
      end

      it 'emails stakeholders' do
        allow(described_class::BaseUpdateImporter).to receive(:perform)
        allow(described_class::BaseUpdate).to receive(:pending_or_failed).and_return([])

        described_class.apply

        expect(ActionMailer::Base.deliveries).not_to be_empty
        expect(ActionMailer::Base.deliveries.last.subject).to include('Tariff updates applied')
        expect(ActionMailer::Base.deliveries.last.encoded).to include('No import warnings found.')
      end

      context 'when reindex_all_indexes arg is not set' do
        subject(:apply) { described_class.apply }

        it 'does not kick off the ClearCacheWorker' do
          allow(described_class::BaseUpdateImporter).to receive(:perform)

          apply

          expect(Sidekiq::Client).not_to have_received(:enqueue).with(ClearCacheWorker)
        end
      end

      context 'when reindex_all_indexes arg is false' do
        subject(:apply) { described_class.apply(reindex_all_indexes: false) }

        it 'does not kick off the ClearCacheWorker' do
          allow(described_class::BaseUpdateImporter).to receive(:perform)

          apply

          expect(Sidekiq::Client).not_to have_received(:enqueue).with(ClearCacheWorker)
        end
      end

      context 'when reindex_all_indexes arg is true' do
        subject(:apply) { described_class.apply(reindex_all_indexes: true) }

        it 'kicks off the ClearCacheWorker' do
          allow(described_class::BaseUpdateImporter).to receive(:perform)
          allow(described_class::BaseUpdate).to receive(:pending_or_failed).and_return([])

          apply

          expect(Sidekiq::Client).to have_received(:enqueue).with(ClearCacheWorker)
        end
      end
    end

    context 'when unsuccessful' do
      before do
        applied_update
        pending_update

        allow(described_class::BaseUpdateImporter).to receive(:perform).with(pending_update).and_raise(Sequel::Rollback)
        allow(Sidekiq::Client).to receive(:enqueue)
      end

      it 'after an error next record is not processed' do
        expect { described_class.apply }.to raise_error(Sequel::Rollback)

        expect(Sidekiq::Client).not_to have_received(:enqueue).with(ClearCacheWorker)
      end
    end

    context 'with failed updates present' do
      let(:failed_update) { create(:taric_update, :failed, example_date: Date.yesterday) }

      before do
        failed_update
      end

      it 'does not apply pending updates' do
        allow(described_class::TaricUpdate).to receive(:pending_at)

        expect { described_class.apply }.to raise_error(described_class::FailedUpdatesError)

        expect(described_class::TaricUpdate).not_to have_received(:pending_at)
      end

      it 'logs the error event' do
        expect_any_instance_of(TariffSynchronizer::Logger).to receive(:failed_updates_present)

        expect { described_class.apply }.to raise_error(described_class::FailedUpdatesError)
      end

      it 'sends email with the error' do
        expect { described_class.apply }.to raise_error(described_class::FailedUpdatesError)
      end

      context 'when reindex_all_indexes arg is true' do
        subject(:apply) { described_class.apply(reindex_all_indexes: true) }

        it 'does not kick off the ClearCacheWorker' do
          allow(Sidekiq::Client).to receive(:enqueue)
          allow(described_class::BaseUpdateImporter).to receive(:perform)

          apply
        rescue StandardError
          expect(Sidekiq::Client).not_to have_received(:enqueue).with(ClearCacheWorker)
        end
      end
    end
  end

  describe 'check sequence of Taric daily updates' do
    let(:applied_sequence_number) { 123 }

    before do
      create(:taric_update, :applied, example_date: Date.today, sequence_number: applied_sequence_number)
      create(:taric_update, :pending, example_date: Date.today, sequence_number: pending_sequence_number)

      allow(TradeTariffBackend).to receive(:with_redis_lock)
      allow(TradeTariffBackend).to receive(:uk?).and_return(false)
    end

    context 'when sequence is correct' do
      let(:pending_sequence_number) { applied_sequence_number + 1 }

      it 'runs the update' do
        described_class.apply

        expect(TradeTariffBackend).to have_received(:with_redis_lock)
      end
    end

    context 'when sequence is NOT correct' do
      let(:pending_sequence_number) { applied_sequence_number + 2 }

      it 'raises a wrong sequence error' do
        expect { described_class.apply }.to raise_error(TariffSynchronizer::FailedUpdatesError)
      end
    end
  end

  describe 'check sequence of CDS daily updates' do
    let(:applied_date) { Date.new(2020, 10, 4) }

    before do
      create :cds_update, :applied, example_date: applied_date,
                                    filename: "tariff_dailyExtract_v1_#{applied_date.strftime('%Y%m%d')}T123456.gzip"

      create :cds_update, example_date: pending_date,
                          filename: "tariff_dailyExtract_v1_#{pending_date.strftime('%Y%m%d')}T123456.gzip"

      allow(TradeTariffBackend).to receive(:with_redis_lock)
    end

    context 'when pending CDS update file is dated as the day after the last applied' do
      let(:pending_date) { applied_date.next }

      it 'runs apply_cds' do
        described_class.apply_cds

        expect(TradeTariffBackend).to have_received(:with_redis_lock)
      end
    end

    context 'when pending CDS update does not respect the sequence' do
      let(:pending_date) { applied_date + 2.days }

      it 'raises and wrong sequence error' do
        expect { described_class.apply_cds }.to raise_error(TariffSynchronizer::FailedUpdatesError)
      end
    end
  end

  describe '.apply_cds' do
    let(:applied_update) { create(:cds_update, :applied, example_date: Date.yesterday) }
    let(:pending_update) { create(:cds_update, :pending, example_date: Date.today) }

    before do
      applied_update
      pending_update

      allow(Sidekiq::Client).to receive(:enqueue)
    end

    context 'when reindex_all_indexes arg is not set' do
      subject(:apply) { described_class.apply_cds }

      it 'does not kick off the ClearCacheWorker' do
        allow(described_class::BaseUpdateImporter).to receive(:perform)

        apply

        expect(Sidekiq::Client).not_to have_received(:enqueue).with(ClearCacheWorker)
      end
    end

    context 'when reindex_all_indexes arg is false' do
      subject(:apply) { described_class.apply_cds(reindex_all_indexes: false) }

      it 'does not kick off the ClearCacheWorker' do
        allow(described_class::BaseUpdateImporter).to receive(:perform)

        apply

        expect(Sidekiq::Client).not_to have_received(:enqueue).with(ClearCacheWorker)
      end
    end

    context 'when reindex_all_indexes arg is true' do
      subject(:apply) { described_class.apply_cds(reindex_all_indexes: true) }

      before do
        allow(described_class::BaseUpdateImporter).to receive(:perform)

        # TODO: why do we even need this?
        allow(described_class::BaseUpdate).to receive(:pending_or_failed).and_return([])
      end

      it 'kicks off the ClearCacheWorker' do
        apply

        expect(Sidekiq::Client).to have_received(:enqueue).with(ClearCacheWorker)
      end
    end

    context 'with failed updates present' do
      before { create :taric_update, :failed }

      context 'when reindex_all_indexes arg is true' do
        subject(:apply) { described_class.apply_cds(reindex_all_indexes: true) }

        it 'does not kick off the ClearCacheWorker' do
          allow(Sidekiq::Client).to receive(:enqueue)
          allow(described_class::BaseUpdateImporter).to receive(:perform)

          apply
        rescue StandardError
          expect(Sidekiq::Client).not_to have_received(:enqueue).with(ClearCacheWorker)
        end
      end
    end
  end
end
# rubocop:enable RSpec/InstanceVariable
# rubocop:enable RSpec/MultipleExpectations
# rubocop:enable RSpec/AnyInstance
