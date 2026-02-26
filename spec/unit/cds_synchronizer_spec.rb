RSpec.describe CdsSynchronizer, :truncation do
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
      let(:exception) { StandardError.new 'Something went wrong' }

      before do
        allow(described_class).to receive(:sync_variables_set?).and_return(true)
        allow(exception).to receive(:backtrace).and_return([])
        allow(TariffSynchronizer::CdsUpdate).to receive(:sync).and_raise(TariffSynchronizer::TariffUpdatesRequester::DownloadException.new('url', exception))
      end

      it 'raises original exception ending the process and logs an error event' do
        expect { described_class.download }.to raise_error StandardError
      end

      it 'sends an email with the exception error', :aggregate_failures do
        ActionMailer::Base.deliveries.clear
        expect { described_class.download }.to raise_error(StandardError)

        expect(ActionMailer::Base.deliveries).not_to be_empty
        expect(ActionMailer::Base.deliveries.last.encoded).to match(/Backtrace/)
        expect(ActionMailer::Base.deliveries.last.encoded).to match(/Trade Tariff download failure/)
      end
    end
  end

  describe '.apply' do
    let(:applied_update) { create(:cds_update, :applied, example_date: Time.zone.yesterday) }
    let(:pending_update) { create(:cds_update, :pending, example_date: Time.zone.today) }

    context 'with failed updates present' do
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
    end
  end

  describe '.rollback' do
    let(:rollback_attributes) { attributes_for :rollback }

    before do
      allow(TradeTariffBackend).to receive(:service).and_return('uk')
      create :cds_update, :applied, :with_measure, example_date: Date.yesterday
      create :cds_update, :applied, :with_measure, example_date: Time.zone.today
    end

    it 'performs a rollback' do
      Sidekiq.testing!(:inline) do
        expect {
          create(:rollback, date: Date.yesterday.beginning_of_day)
        }.to change(Measure, :count).from(2).to(1)
      end
    end

    it 'marks tariff changes as pending' do
      tariff_change_job = TariffChangesJobStatus.create(operation_date: Date.yesterday)
      tariff_change_job.mark_changes_generated!

      Sidekiq.testing!(:inline) do
        create(:rollback, date: Date.yesterday.beginning_of_day)
      end

      expect(tariff_change_job.reload).to be_changes_pending
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

      before { allow(SlackNotifierService).to receive(:call) }

      it 'raises wrong sequence error and notifies Slack app', :aggregate_failures do
        expect { described_class.apply }.to raise_error(TariffSynchronizer::FailedUpdatesError)
        expect(SlackNotifierService).to have_received(:call)
      end
    end
  end
end
