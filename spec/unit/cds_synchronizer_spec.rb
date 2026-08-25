RSpec.describe CdsSynchronizer, :truncation do
  describe '.update_type' do
    it 'always returns CdsUpdate regardless of the SERVICE env var' do
      expect(described_class.update_type).to eq(TariffSynchronizer::CdsUpdate)
    end
  end

  describe '.initial_update_date' do
    it 'returns initial update date' do
      expect(described_class.initial_update_date).to eq(Date.new(2020, 9, 1))
    end
  end

  describe '.download' do
    context 'when sync variables are set' do
      before do
        allow(described_class).to receive(:sync_variables_set?).and_return(true)
      end

      it 'invokes update downloading/syncing on all update types' do
        allow(TariffSynchronizer::CdsUpdate).to receive(:sync).and_return(true)

        described_class.download

        expect(TariffSynchronizer::CdsUpdate).to have_received(:sync)
      end

      it 'emits a download_completed instrumentation event' do
        allow(TariffSynchronizer::CdsUpdate).to receive(:sync).and_return(true)
        allow(TariffSynchronizer::Instrumentation).to receive(:download_completed)

        described_class.download

        expect(TariffSynchronizer::Instrumentation).to have_received(:download_completed)
      end
    end

    context 'when sync variables are not set' do
      before do
        allow(described_class).to receive(:sync_variables_set?).and_return(false)
      end

      it 'does not start sync process' do
        allow(TariffSynchronizer::CdsUpdate).to receive(:sync)

        described_class.download

        expect(TariffSynchronizer::CdsUpdate).not_to have_received(:sync)
      end

      it 'emits a sync_run_failed instrumentation event' do
        allow(TariffSynchronizer::Instrumentation).to receive(:sync_run_failed)

        described_class.download

        expect(TariffSynchronizer::Instrumentation).to have_received(:sync_run_failed)
      end
    end

    context 'when a download exception' do
      before do
        allow(described_class).to receive(:sync_variables_set?).and_return(true)
        allow(TariffSynchronizer::CdsUpdate).to receive(:sync)
          .and_raise(TariffSynchronizer::TariffUpdatesRequester::RetriableDownloadError.new('url'))
      end

      it 'raises a retriable download error ending the process' do
        expect { described_class.download }.to raise_error TariffSynchronizer::TariffUpdatesRequester::RetriableDownloadError
      end
    end
  end

  describe '.apply' do
    let(:applied_update) { create(:cds_update, :applied, example_date: Time.zone.yesterday) }
    let(:pending_update) { create(:cds_update, :pending, example_date: Time.zone.today) }

    context 'when the Redis lock cannot be acquired' do
      before do
        allow(TradeTariffBackend).to receive(:with_redis_lock).and_raise(Redlock::LockError, 'tariff-lock')
        allow(TariffSynchronizer::BaseUpdate).to receive(:failed)
      end

      it 'does not run failure or sequence checks' do
        described_class.apply

        expect(TariffSynchronizer::BaseUpdate).not_to have_received(:failed)
      end
    end

    context 'with failed CDS updates present' do
      let(:failed_update) { create(:cds_update, :failed, example_date: Time.zone.yesterday) }

      before do
        failed_update
        allow(TradeTariffBackend).to receive(:service).and_return('uk')
      end

      it 'does not apply pending updates', :aggregate_failures do
        allow(TariffSynchronizer::CdsUpdate).to receive(:pending_at)

        expect { described_class.apply }.to raise_error(TariffSynchronizer::FailedUpdatesError)

        expect(TariffSynchronizer::CdsUpdate).not_to have_received(:pending_at)
      end

      it 'emits a failed_updates_detected instrumentation event', :aggregate_failures do
        allow(TariffSynchronizer::Instrumentation).to receive(:failed_updates_detected)

        expect { described_class.apply }.to raise_error(TariffSynchronizer::FailedUpdatesError)

        expect(TariffSynchronizer::Instrumentation).to have_received(:failed_updates_detected)
      end

      it 'sends email with the error' do
        expect { described_class.apply }.to raise_error(TariffSynchronizer::FailedUpdatesError)
      end

      it 'routes the failure notification to #production-alerts slack channel' do
        allow(SlackNotifierService).to receive(:call)

        expect { described_class.apply }.to raise_error(TariffSynchronizer::FailedUpdatesError)

        expect(SlackNotifierService).to have_received(:call).with(
          text: 'Error TariffSynchronizer::FailedUpdatesError: TariffSynchronizer::FailedUpdatesError',
          channel: TradeTariffBackend.slack_failures_channel,
        )
      end
    end

    context 'with only TARIC failed updates present' do
      before do
        create(:taric_update, :failed, example_date: Time.zone.yesterday)
        allow(TradeTariffBackend).to receive(:service).and_return('uk')
        allow(TradeTariffBackend).to receive(:with_redis_lock)
      end

      it 'does not raise FailedUpdatesError' do
        expect { described_class.apply }.not_to raise_error
      end
    end
  end

  describe '.rollback' do
    let(:rollback_attributes) { attributes_for :rollback }
    let(:rollback_date) { Date.yesterday }

    before do
      allow(TradeTariffBackend).to receive(:service).and_return('uk')
      create :cds_update, :applied, :with_measure, example_date: rollback_date
      create :cds_update, :applied, :with_measure, example_date: Time.zone.today
    end

    it 'performs a rollback' do
      Sidekiq.testing!(:inline) do
        expect {
          create(:rollback, date: rollback_date.beginning_of_day)
        }.to change(Measure, :count).from(2).to(1)
      end
    end

    it 'marks tariff changes as pending' do
      tariff_change_job = TariffChangesJobStatus.create(operation_date: rollback_date)
      tariff_change_job.mark_changes_generated!

      Sidekiq.testing!(:inline) do
        create(:rollback, date: rollback_date.beginning_of_day)
      end

      expect(tariff_change_job.reload).to be_changes_pending
    end

    it 'emits lock and completion instrumentation with the affected file count', :aggregate_failures do
      allow(TariffSynchronizer::Instrumentation).to receive(:lock_acquired)
      allow(TariffSynchronizer::Instrumentation).to receive(:rollback_completed)
      allow(TradeTariffBackend).to receive(:with_redis_lock).and_yield

      described_class.rollback(rollback_date, keep: true)

      expect(TariffSynchronizer::Instrumentation).to have_received(:lock_acquired).with(phase: 'rollback')
      expect(TariffSynchronizer::Instrumentation).to have_received(:rollback_completed).with(
        rollback_date: rollback_date.iso8601,
        duration_ms: be_a(Numeric),
        files_count: 1,
      )
    end

    context 'when the Redis lock cannot be acquired' do
      before do
        allow(TradeTariffBackend).to receive(:with_redis_lock).and_raise(Redlock::LockError, 'tariff-lock')
        allow(TariffSynchronizer::Instrumentation).to receive(:lock_failed)
        allow(TariffSynchronizer::Instrumentation).to receive(:rollback_completed)
      end

      it 'leaves tariff data unchanged and emits lock-failure instrumentation', :aggregate_failures do
        expect { described_class.rollback(rollback_date) }.not_to change(Measure, :count)

        expect(TariffSynchronizer::Instrumentation).to have_received(:lock_failed).with(phase: 'rollback')
        expect(TariffSynchronizer::Instrumentation).not_to have_received(:rollback_completed)
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
        described_class.apply

        expect(TradeTariffBackend).to have_received(:with_redis_lock)
      end
    end

    context 'when pending CDS update does not respect the sequence' do
      let(:pending_date) { applied_date + 2.days }

      before do
        allow(SlackNotifierService).to receive(:call)
        allow(TradeTariffBackend).to receive(:with_redis_lock).and_yield
      end

      it 'raises wrong sequence error and notifies Slack app', :aggregate_failures do
        expect { described_class.apply }.to raise_error(TariffSynchronizer::FailedUpdatesError)
        expect(SlackNotifierService).to have_received(:call)
      end
    end
  end
end
