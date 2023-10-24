RSpec.describe CdsSynchronizer, truncation: true do
  describe '.initial_update_date' do
    it 'returns initial update date ' do
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

      it 'logs an info event' do
        allow(TariffSynchronizer::CdsUpdate).to receive(:sync).and_return(true)
        allow(Rails.logger).to receive(:info)

        described_class.download

        expect(Rails.logger).to have_received(:info)
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

      it 'logs an error event' do
        allow(Rails.logger).to receive(:error)

        described_class.download

        expect(Rails.logger).to have_received(:error)
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

      it 'sends an email with the exception error' do
        ActionMailer::Base.deliveries.clear
        expect { described_class.download }.to raise_error(StandardError)

        expect(ActionMailer::Base.deliveries).not_to be_empty
        expect(ActionMailer::Base.deliveries.last.encoded).to match(/Backtrace/)
        expect(ActionMailer::Base.deliveries.last.encoded).to match(/Trade Tariff download failure/)
      end
    end
  end

  describe '.apply' do
    let(:applied_update) { create(:taric_update, :applied, example_date: Time.zone.yesterday) }
    let(:pending_update) { create(:taric_update, :pending, example_date: Time.zone.today) }

    context 'with failed updates present' do
      let(:failed_update) { create(:taric_update, :failed, example_date: Time.zone.yesterday) }

      before do
        failed_update
      end

      it 'does not apply pending updates' do
        allow(TariffSynchronizer::TaricUpdate).to receive(:pending_at)

        expect { described_class.apply }.to raise_error(TariffSynchronizer::FailedUpdatesError)

        expect(TariffSynchronizer::TaricUpdate).not_to have_received(:pending_at)
      end

      it 'logs the error event' do
        allow(Rails.logger).to receive(:error)

        expect { described_class.apply }.to raise_error(TariffSynchronizer::FailedUpdatesError)

        expect(Rails.logger).to have_received(:error)
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

      it 'raises a wrong sequence error and notifies Slack app' do
        allow(SlackNotifierService).to receive(:call)

        expect {
          described_class.apply
        }.to raise_error(TariffSynchronizer::FailedUpdatesError)

        expect(SlackNotifierService).to have_received(:call)
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

      it 'raises wrong sequence error and notifies Slack app' do
        allow(SlackNotifierService).to receive(:call)

        expect { described_class.apply }.to raise_error(TariffSynchronizer::FailedUpdatesError)

        expect(SlackNotifierService).to have_received(:call)
      end
    end
  end
end
# rubocop:enable RSpec/MultipleExpectations
