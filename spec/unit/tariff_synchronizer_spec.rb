require 'rails_helper'

describe TariffSynchronizer, truncation: true do
  describe '.initial_update_date_for' do
    # helper method where update type is a param
    it 'returns initial update date for specific update type taric or chief ' do
      expect(TariffSynchronizer.initial_update_date_for(:taric)).to eq(TariffSynchronizer.taric_initial_update_date)
      expect(TariffSynchronizer.initial_update_date_for(:chief)).to eq(TariffSynchronizer.chief_initial_update_date)
      expect(TariffSynchronizer.initial_update_date_for(:cds)).to eq(TariffSynchronizer.cds_initial_update_date)
      expect { TariffSynchronizer.initial_update_date_for(:non_existent) }.to raise_error(NoMethodError)
    end
  end

  describe '.download' do
    context 'sync variables are set' do
      before do
        allow(TariffSynchronizer).to receive(:sync_variables_set?).and_return(true)
      end

      it 'invokes update downloading/syncing on all update types' do
        expect(TariffSynchronizer::TaricUpdate).to receive(:sync).and_return(true)
        expect(TariffSynchronizer::ChiefUpdate).to receive(:sync).and_return(true)

        TariffSynchronizer.download
      end

      it 'logs an info event' do
        allow(TariffSynchronizer::TaricUpdate).to receive(:sync).and_return(true)
        allow(TariffSynchronizer::ChiefUpdate).to receive(:sync).and_return(true)
        tariff_synchronizer_logger_listener
        TariffSynchronizer.download
        expect(@logger.logged(:info).size).to eq 1
        expect(@logger.logged(:info).last).to match(/Finished downloading updates/)
      end
    end

    context 'sync variables are not set' do
      it 'does not start sync process' do
        allow(TariffSynchronizer).to receive(:sync_variables_set?).and_return(false)

        expect(TariffSynchronizer::TaricUpdate).not_to receive(:sync)
        expect(TariffSynchronizer::ChiefUpdate).not_to receive(:sync)

        TariffSynchronizer.download
      end

      it 'logs an error event' do
        tariff_synchronizer_logger_listener
        allow(TariffSynchronizer).to receive(:sync_variables_set?).and_return(false)

        TariffSynchronizer.download

        expect(@logger.logged(:error).size).to eq 1
        expect(@logger.logged(:error).last).to match(/Missing: Tariff sync enviroment variables/)
      end
    end

    context 'when a download exception' do
      before do
        expect(TariffSynchronizer).to receive(:sync_variables_set?).and_return(true)
        allow_any_instance_of(Curl::Easy).to receive(:perform)
                                         .and_raise(Curl::Err::HostResolutionError)
      end

      it 'raises original exception ending the process and logs an error event' do
        tariff_synchronizer_logger_listener
        expect { TariffSynchronizer.download }.to raise_error Curl::Err::HostResolutionError
        expect(@logger.logged(:error).size).to eq 1
        expect(@logger.logged(:error).last).to match(/Download failed/)
      end

      it 'sends an email with the exception error' do
        ActionMailer::Base.deliveries.clear
        expect { TariffSynchronizer.download }.to raise_error(Curl::Err::HostResolutionError)

        expect(ActionMailer::Base.deliveries).not_to be_empty
        expect(ActionMailer::Base.deliveries.last.encoded).to match(/Backtrace/)
        expect(ActionMailer::Base.deliveries.last.encoded).to match(/Curl::Err::HostResolutionError/)
      end
    end
  end

  describe '.apply' do
    let(:update_1) { instance_double('TariffSynchronizer::TaricUpdate', issue_date: Date.yesterday, filename: Date.yesterday) }
    let(:update_2) { instance_double('TariffSynchronizer::TaricUpdate', issue_date: Date.current, filename: Date.current) }

    context 'success scenario' do
      before do
        allow(TariffSynchronizer).to receive(:date_range_since_last_pending_update).and_return([Date.yesterday, Date.current])
        expect(TariffSynchronizer::TaricUpdate).to receive(:pending_at).with(update_1.issue_date).and_return([update_1])
        expect(TariffSynchronizer::TaricUpdate).to receive(:pending_at).with(update_2.issue_date).and_return([update_2])
      end

      it 'all pending updates get applied' do
        expect(TariffSynchronizer::BaseUpdateImporter).to receive(:perform).with(update_1)
        expect(TariffSynchronizer::BaseUpdateImporter).to receive(:perform).with(update_2)

        TariffSynchronizer.apply
      end

      it 'logs the info event and send email' do
        allow(TariffSynchronizer::BaseUpdateImporter).to receive(:perform).with(update_1).and_return(true)
        allow(TariffSynchronizer::BaseUpdateImporter).to receive(:perform).with(update_2).and_return(true)
        tariff_synchronizer_logger_listener

        TariffSynchronizer.apply

        expect(@logger.logged(:info).size).to eq(3)
        expect(@logger.logged(:info).last).to include('Finished applying updates')
        expect(ActionMailer::Base.deliveries).not_to be_empty
        expect(ActionMailer::Base.deliveries.last.subject).to include('Tariff updates applied')
        expect(ActionMailer::Base.deliveries.last.encoded).to include('No conformance errors found.')
        expect(ActionMailer::Base.deliveries.last.encoded).to include('No import warnings found.')
      end
    end

    context 'failure scenario' do
      before do
        allow(TariffSynchronizer).to receive(:date_range_since_last_pending_update).and_return([Date.yesterday, Date.current])
        allow(TariffSynchronizer::TaricUpdate).to receive(:pending_at).with(update_1.issue_date).and_return([update_1])
        allow(TariffSynchronizer::BaseUpdateImporter).to receive(:perform).with(update_1).and_raise(Sequel::Rollback)
      end

      it 'after an error next record is not processed' do
        expect { TariffSynchronizer.apply }.to raise_error(Sequel::Rollback)
        expect(TariffSynchronizer::BaseUpdateImporter).not_to receive(:perform).with(update_2)
      end
    end

    context 'with failed updates present' do
      before { create :taric_update, :failed }

      it 'does not apply pending updates' do
        expect(TariffSynchronizer::TaricUpdate).not_to receive(:pending_at)
        expect(TariffSynchronizer::ChiefUpdate).not_to receive(:pending_at)

        expect { TariffSynchronizer.apply }.to raise_error(TariffSynchronizer::FailedUpdatesError)
      end

      it 'logs the error event' do
        tariff_synchronizer_logger_listener
        expect { TariffSynchronizer.apply }.to raise_error(TariffSynchronizer::FailedUpdatesError)

        expect(@logger.logged(:error).size).to eq(1)
        expect(@logger.logged(:error).last).to include('TariffSynchronizer found failed updates that need to be fixed before running:')
      end

      it 'sends email with the error' do
        expect { TariffSynchronizer.apply }.to raise_error(TariffSynchronizer::FailedUpdatesError)
      end
    end
  end
end
