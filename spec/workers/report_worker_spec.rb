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
      allow(DifferencesReportWorker).to receive(:perform_in).and_call_original
      allow(TradeTariffBackend).to receive(:service).and_return(service)
      travel_to Date.parse(date).beginning_of_day
    end

    shared_examples 'all reports are generated' do
      it { expect(Reporting::Commodities).to have_received(:generate) }
      it { expect(Reporting::Basic).to have_received(:generate) }
      it { expect(Reporting::SupplementaryUnits).to have_received(:generate) }
      it { expect(Reporting::DeclarableDuties).to have_received(:generate) }
      it { expect(Reporting::GeographicalAreaGroups).to have_received(:generate) }
      it { expect(Reporting::Prohibitions).to have_received(:generate) }
      it { expect(Reporting::CategoryAssessments).to have_received(:generate) }
    end

    context 'with default behaviour' do
      before { worker.perform }

      context 'when on the xi service' do
        let(:service) { 'xi' }

        it_behaves_like 'all reports are generated'
        it { expect(DifferencesReportWorker).not_to have_received(:perform_in) }
      end

      context 'when on the uk service and the day is a monday' do
        let(:service) { 'uk' }

        it_behaves_like 'all reports are generated'
        it { expect(DifferencesReportWorker).to have_received(:perform_in) }
      end

      context 'when on the uk service and the day is not a monday' do
        let(:service) { 'uk' }
        let(:date) { '2023-10-31' }

        it_behaves_like 'all reports are generated'
        it { expect(DifferencesReportWorker).not_to have_received(:perform_in) }
      end
    end

    context 'without scheduling differences report' do
      before { worker.perform(false) }

      let(:service) { 'uk' }

      it_behaves_like 'all reports are generated'
      it { expect(DifferencesReportWorker).not_to have_received(:perform_in) }
    end
  end
end
