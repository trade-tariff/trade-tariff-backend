RSpec.describe ReportWorker, type: :worker do
  subject(:worker) { described_class.new }

  describe '#perform' do
    let(:date) { '2023-10-30' } # a monday

    before do
      allow(Reporting::Commodities).to receive(:generate)
      allow(Reporting::Basic).to receive(:generate)
      allow(Reporting::SupplementaryUnits).to receive(:generate)
      allow(Reporting::DeclarableDuties).to receive(:generate)
      allow(Reporting::GeographicalAreaGroups).to receive(:generate)
      allow(Reporting::Prohibitions).to receive(:generate)
      allow(Reporting::CategoryAssessments).to receive(:generate).and_call_original
      allow(Reporting::CdsUpdates).to receive(:generate)
      allow(DifferencesReportWorker).to receive(:perform_in).and_call_original
      allow(TradeTariffBackend).to receive(:service).and_return(service)
      travel_to Date.parse(date).beginning_of_day
    end

    shared_examples 'core reports are generated' do
      it { expect(Reporting::Commodities).to have_received(:generate) }
      it { expect(Reporting::Basic).to have_received(:generate) }
      it { expect(Reporting::SupplementaryUnits).to have_received(:generate) }
      it { expect(Reporting::DeclarableDuties).to have_received(:generate) }
      it { expect(Reporting::GeographicalAreaGroups).to have_received(:generate) }
      it { expect(Reporting::Prohibitions).to have_received(:generate) }
      it { expect(Reporting::CategoryAssessments).to have_received(:generate) }
    end

    shared_examples 'cds updates report is generated' do
      it { expect(Reporting::CdsUpdates).to have_received(:generate) }
    end

    shared_examples 'cds updates report is skipped' do
      it { expect(Reporting::CdsUpdates).not_to have_received(:generate) }
    end

    context 'with default behaviour' do
      before { worker.perform }

      context 'when on the xi service' do
        let(:service) { 'xi' }

        it_behaves_like 'core reports are generated'
        it_behaves_like 'cds updates report is skipped'
        it { expect(DifferencesReportWorker).not_to have_received(:perform_in) }
      end

      context 'when on the uk service and the day is the second monday of the month' do
        let(:service) { 'uk' }
        let(:date) { '2023-10-09' }

        it_behaves_like 'core reports are generated'
        it_behaves_like 'cds updates report is generated'
        it { expect(DifferencesReportWorker).to have_received(:perform_in) }
      end

      context 'when on the uk service and the day is a monday but not the second monday' do
        let(:service) { 'uk' }
        let(:date) { '2023-10-30' }

        it_behaves_like 'core reports are generated'
        it_behaves_like 'cds updates report is skipped'
        it { expect(DifferencesReportWorker).to have_received(:perform_in) }
      end

      context 'when on the uk service and the day is not a monday' do
        let(:service) { 'uk' }
        let(:date) { '2023-10-31' }

        it_behaves_like 'core reports are generated'
        it_behaves_like 'cds updates report is skipped'
        it { expect(DifferencesReportWorker).not_to have_received(:perform_in) }
      end
    end

    context 'without scheduling differences report' do
      before { worker.perform(false) }

      let(:service) { 'uk' }

      it_behaves_like 'core reports are generated'
      it_behaves_like 'cds updates report is skipped'
      it { expect(DifferencesReportWorker).not_to have_received(:perform_in) }
    end

    context 'when a report fails' do
      let(:service) { 'uk' }

      before do
        allow(Reporting::DeclarableDuties).to receive(:generate).and_raise(Sequel::DatabaseConnectionError)
      end

      it 'still generates subsequent reports' do
        expect { worker.perform }.to raise_error(Sequel::DatabaseConnectionError)

        expect(Reporting::GeographicalAreaGroups).to have_received(:generate)
        expect(Reporting::CategoryAssessments).to have_received(:generate)
      end

      it 'logs the failure' do
        allow(Rails.logger).to receive(:error)

        expect { worker.perform }.to raise_error(Sequel::DatabaseConnectionError)

        expect(Rails.logger).to have_received(:error).with(/DeclarableDuties.*failed/)
      end
    end
  end
end
