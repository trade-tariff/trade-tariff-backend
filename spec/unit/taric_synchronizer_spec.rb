RSpec.describe TaricSynchronizer, :truncation do
  describe '.update_type' do
    it 'always returns TaricUpdate regardless of the SERVICE env var' do
      expect(described_class.update_type).to eq(TariffSynchronizer::TaricUpdate)
    end
  end

  describe '.initial_update_date' do
    it 'returns initial update date' do
      expect(described_class.initial_update_date).to eq(Date.new(2012, 6, 6))
    end
  end

  describe '.download' do
    it 'delegates to TaricUpdateDownloader' do
      allow(TariffSynchronizer::TaricUpdateDownloader).to receive(:download)

      described_class.download

      expect(TariffSynchronizer::TaricUpdateDownloader).to have_received(:download)
        .with(initial_date: described_class.initial_update_date)
    end
  end

  describe '.apply' do
    let(:applied_update) { create(:taric_update, :applied, example_date: Time.zone.yesterday) }
    let(:pending_update) { create(:taric_update, :pending, example_date: Time.zone.today) }

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

    context 'when successful' do
      let(:taric_importer) { instance_double(TaricImporter, import: nil) }

      before do
        allow(TaricImporter).to receive(:new).and_return(taric_importer)
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

    context 'with failed TARIC updates present' do
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

    context 'with only CDS failed updates present' do
      before do
        create(:cds_update, :failed, example_date: Time.zone.yesterday)
        allow(TradeTariffBackend).to receive(:service).and_return('xi')
        allow(TradeTariffBackend).to receive(:with_redis_lock)
      end

      it 'does not raise FailedUpdatesError' do
        expect { described_class.apply }.not_to raise_error
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

      before do
        allow(TradeTariffBackend).to receive(:with_redis_lock).and_yield
      end

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
    before do
      allow(TradeTariffBackend).to receive(:service).and_return('xi')
      create :taric_update, :applied, :with_measure, example_date: Date.yesterday
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
