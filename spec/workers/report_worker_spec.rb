RSpec.describe ReportWorker, type: :worker do
  subject(:worker) { described_class.new }

  describe '#perform' do
    let(:differences) { Reporting::Differences.new }

    before do
      allow(Reporting::Commodities).to receive(:generate)
      allow(Reporting::Basic).to receive(:generate)
      allow(Reporting::SupplementaryUnits).to receive(:generate)
      allow(Reporting::DeclarableDuties).to receive(:generate)
      allow(Reporting::GeographicalAreaGroups).to receive(:generate)
      allow(Reporting::Prohibitions).to receive(:generate)
      allow(Reporting::Differences).to receive(:generate).and_return(differences)
    end

    shared_examples 'a report worker' do |service|
      before do
        allow(TradeTariffBackend).to receive(:service).and_return(service)

        worker.perform
      end

      it { expect(Reporting::Commodities).to have_received(:generate) }
      it { expect(Reporting::Basic).to have_received(:generate) }
      it { expect(Reporting::SupplementaryUnits).to have_received(:generate) }
      it { expect(Reporting::DeclarableDuties).to have_received(:generate) }
      it { expect(Reporting::GeographicalAreaGroups).to have_received(:generate) }
      it { expect(Reporting::Prohibitions).to have_received(:generate) }

      if service == 'uk'
        it { expect(Reporting::Differences).to have_received(:generate) }
        it { expect(ActionMailer::Base.deliveries.count).to eq(1) }
      else
        it { expect(Reporting::Differences).not_to have_received(:generate) }
        it { expect(ActionMailer::Base.deliveries.count).to eq(0) }
      end
    end

    it_behaves_like 'a report worker', 'uk'
    it_behaves_like 'a report worker', 'xi'
  end
end
