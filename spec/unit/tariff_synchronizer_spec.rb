# rubocop:disable RSpec/InstanceVariable
# rubocop:disable RSpec/MultipleExpectations
# rubocop:disable RSpec/AnyInstance
describe TariffSynchronizer, truncation: true do
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
        allow(described_class::TaricUpdate).to receive(:sync).and_return(true)
        tariff_synchronizer_logger_listener
        described_class.download
        expect(@logger.logged(:info).size).to eq 1
        expect(@logger.logged(:info).last).to match(/Finished downloading updates/)
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
        tariff_synchronizer_logger_listener
        allow(described_class).to receive(:sync_variables_set?).and_return(false)

        described_class.download

        expect(@logger.logged(:error).size).to eq 1
        expect(@logger.logged(:error).last).to match(/Missing: Tariff sync enviroment variables/)
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
    let(:update_1) { instance_double('described_class::TaricUpdate', issue_date: Date.yesterday, filename: Date.yesterday) }
    let(:update_2) { instance_double('described_class::TaricUpdate', issue_date: Date.current, filename: Date.current) }

    context 'when successful' do
      before do
        allow(described_class).to receive(:date_range_since_last_pending_update).and_return([Date.yesterday, Date.current])
        allow(described_class::TaricUpdate).to receive(:pending_at).with(update_1.issue_date).and_return([update_1])
        allow(described_class::TaricUpdate).to receive(:pending_at).with(update_2.issue_date).and_return([update_2])
      end

      it 'all pending updates get applied' do
        allow(described_class::BaseUpdateImporter).to receive(:perform)

        described_class.apply

        expect(described_class::BaseUpdateImporter).to have_received(:perform).with(update_1)
        expect(described_class::BaseUpdateImporter).to have_received(:perform).with(update_2)
      end

      it 'logs the info event and send email' do
        allow(described_class::BaseUpdateImporter).to receive(:perform).with(update_1).and_return(true)
        allow(described_class::BaseUpdateImporter).to receive(:perform).with(update_2).and_return(true)

        tariff_synchronizer_logger_listener

        described_class.apply

        expect(@logger.logged(:info).size).to eq(3)
        expect(@logger.logged(:info).last).to include('Finished applying updates')
        expect(ActionMailer::Base.deliveries).not_to be_empty
        expect(ActionMailer::Base.deliveries.last.subject).to include('Tariff updates applied')
        expect(ActionMailer::Base.deliveries.last.encoded).to include('No import warnings found.')
      end
    end

    context 'when unsuccessful' do
      before do
        allow(described_class).to receive(:date_range_since_last_pending_update).and_return([Date.yesterday, Date.current])
        allow(described_class::TaricUpdate).to receive(:pending_at).with(update_1.issue_date).and_return([update_1])
        allow(described_class::BaseUpdateImporter).to receive(:perform).with(update_1).and_raise(Sequel::Rollback)
      end

      it 'after an error next record is not processed' do
        expect { described_class.apply }.to raise_error(Sequel::Rollback)
        expect(described_class::BaseUpdateImporter).not_to have_received(:perform).with(update_2)
      end
    end

    context 'with failed updates present' do
      before { create :taric_update, :failed }

      it 'does not apply pending updates' do
        allow(described_class::TaricUpdate).to receive(:pending_at)
        expect { described_class.apply }.to raise_error(described_class::FailedUpdatesError)
        expect(described_class::TaricUpdate).not_to have_received(:pending_at)
      end

      it 'logs the error event' do
        tariff_synchronizer_logger_listener
        expect { described_class.apply }.to raise_error(described_class::FailedUpdatesError)

        expect(@logger.logged(:error).size).to eq(1)
        expect(@logger.logged(:error).last).to include('TariffSynchronizer found failed updates that need to be fixed before running:')
      end

      it 'sends email with the error' do
        expect { described_class.apply }.to raise_error(described_class::FailedUpdatesError)
      end
    end
  end
end
# rubocop:enable RSpec/InstanceVariable
# rubocop:enable RSpec/MultipleExpectations
# rubocop:enable RSpec/AnyInstance
