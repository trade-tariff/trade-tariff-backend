# rubocop:disable RSpec/AnyInstance
RSpec.describe TaricSynchronizer, :truncation do
  describe '.initial_update_date' do
    it 'returns initial update date' do
      expect(described_class.initial_update_date).to eq(Date.new(2012, 6, 6))
    end
  end

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

      it 'emits a download_completed instrumentation event' do
        allow(TariffSynchronizer::TaricUpdate).to receive(:sync).and_return(true)
        allow(TariffSynchronizer::Instrumentation).to receive(:download_completed)

        described_class.download

        expect(TariffSynchronizer::Instrumentation).to have_received(:download_completed)
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
      before do
        allow(described_class).to receive(:sync_variables_set?).and_return(false)
      end

      it 'does not start sync process' do
        allow(TariffSynchronizer::TaricUpdate).to receive(:sync)

        described_class.download

        expect(TariffSynchronizer::TaricUpdate).not_to have_received(:sync)
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
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::Error, 'Foo')
      end

      it 'raises original exception ending the process and emits a download_failed event' do
        allow(TariffSynchronizer::Instrumentation).to receive(:download_failed)

        expect { described_class.download }.to raise_error Faraday::Error
        expect(TariffSynchronizer::Instrumentation).to have_received(:download_failed)
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
        allow_any_instance_of(TaricImporter).to receive(:import)
        allow(TariffSynchronizer::TariffLogger).to receive(:failed_update)
        allow(TradeTariffBackend).to receive(:service).and_return('xi')
        applied_update
        pending_update
      end

      it 'returns true to mark successful application of updates' do
        expect(described_class.apply).to be_truthy
      end

      it 'all pending updates get applied' do
        allow(TariffSynchronizer::BaseUpdateImporter).to receive(:perform).and_call_original

        expect(described_class.apply).to be_truthy

        expect(TariffSynchronizer::BaseUpdateImporter).to have_received(:perform).with(pending_update)
      end

      it 'emails stakeholders' do
        allow(TariffSynchronizer::BaseUpdateImporter).to receive(:perform).and_call_original
        allow(TariffSynchronizer::BaseUpdate).to receive(:pending_or_failed).and_return([])

        described_class.apply

        expect(ActionMailer::Base.deliveries).not_to be_empty
        expect(ActionMailer::Base.deliveries.last.subject).to include('Tariff updates applied')
        expect(ActionMailer::Base.deliveries.last.encoded).to include('No import warnings found.')
      end
    end

    context 'when unsuccessful' do
      before do
        applied_update
        pending_update
        allow(TradeTariffBackend).to receive(:service).and_return('xi')
        allow(TariffSynchronizer::BaseUpdateImporter).to receive(:perform).with(pending_update).and_raise(Sequel::Rollback)
      end

      it 'after an error next record is not processed' do
        expect { described_class.apply }.to raise_error(Sequel::Rollback)
      end
    end

    context 'with failed updates present' do
      let(:failed_update) { create(:taric_update, :failed, example_date: Time.zone.yesterday) }

      before do
        failed_update
        allow(TradeTariffBackend).to receive(:service).and_return('xi')
      end

      it 'does not apply pending updates' do
        allow(TariffSynchronizer::TaricUpdate).to receive(:pending_at)

        expect { described_class.apply }.to raise_error(TariffSynchronizer::FailedUpdatesError)

        expect(TariffSynchronizer::TaricUpdate).not_to have_received(:pending_at)
      end

      it 'emits a failed_updates_detected instrumentation event' do
        allow(TariffSynchronizer::Instrumentation).to receive(:failed_updates_detected)
        expect { described_class.apply }.to raise_error(TariffSynchronizer::FailedUpdatesError)

        expect(TariffSynchronizer::Instrumentation).to have_received(:failed_updates_detected)
      end

      it 'sends email with the error' do
        expect { described_class.apply }.to raise_error(TariffSynchronizer::FailedUpdatesError)
      end
    end
  end

  describe 'check sequence of Taric daily updates' do
    let(:applied_sequence_number) { 123 }

    before do
      create(:taric_update, :applied, example_date: Time.zone.yesterday, sequence_number: applied_sequence_number)
      create(:taric_update, :pending, example_date: Time.zone.today, sequence_number: pending_sequence_number)

      allow(TradeTariffBackend).to receive(:with_redis_lock)
      allow(TradeTariffBackend).to receive(:service).and_return('xi')
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

      it 'raises a wrong sequence error and notifies Slack app' do
        allow(SlackNotifierService).to receive(:call)

        expect {
          described_class.apply
        }.to raise_error(TariffSynchronizer::FailedUpdatesError)

        expect(SlackNotifierService).to have_received(:call)
      end
    end
  end

  describe '.rollback' do
    let(:rollback_attributes) { attributes_for :rollback }
    let(:record) do
      create :measure, operation_date: Time.zone.yesterday.to_date
    end

    before do
      record
      allow(TradeTariffBackend).to receive(:service).and_return('xi')
    end

    it 'performs a rollback' do
      Sidekiq.testing!(:inline) do
        expect {
          create(:rollback, date: 1.month.ago.beginning_of_day)
        }.to change(Measure, :count).from(1).to(0)
      end
    end
  end
end
# rubocop:enable RSpec/MultipleExpectations
# rubocop:enable RSpec/AnyInstance
