RSpec.describe ReportWorker, type: :worker do
  subject(:worker) { described_class.new }

  describe '#perform' do
    let(:differences) { Reporting::Differences.new }
    let(:date) { Time.zone.today.iso8601 }

    before do
      allow(Reporting::Commodities).to receive(:generate)
      allow(Reporting::Basic).to receive(:generate)
      allow(Reporting::SupplementaryUnits).to receive(:generate)
      allow(Reporting::DeclarableDuties).to receive(:generate)
      allow(Reporting::GeographicalAreaGroups).to receive(:generate)
      allow(Reporting::Prohibitions).to receive(:generate)
      allow(Reporting::Differences).to receive(:generate).and_return(differences)
      allow(TradeTariffBackend).to receive(:service).and_return(service)
      travel_to Date.parse(date).beginning_of_day

      worker.perform
    end

    after do
      travel_back
    end

    context 'when on the xi service' do
      let(:service) { 'xi' }

      it { expect(Reporting::Commodities).to have_received(:generate) }
      it { expect(Reporting::Basic).to have_received(:generate) }
      it { expect(Reporting::SupplementaryUnits).to have_received(:generate) }
      it { expect(Reporting::DeclarableDuties).to have_received(:generate) }
      it { expect(Reporting::GeographicalAreaGroups).to have_received(:generate) }
      it { expect(Reporting::Prohibitions).to have_received(:generate) }
      it { expect(Reporting::Differences).not_to have_received(:generate) }
      it { expect(ActionMailer::Base.deliveries.count).to eq(0) }
    end

    context 'when on the uk service and the day is a monday' do
      let(:service) { 'uk' }
      let(:date) { '2023-10-30' }

      it { expect(Reporting::Commodities).to have_received(:generate) }
      it { expect(Reporting::Basic).to have_received(:generate) }
      it { expect(Reporting::SupplementaryUnits).to have_received(:generate) }
      it { expect(Reporting::DeclarableDuties).to have_received(:generate) }
      it { expect(Reporting::GeographicalAreaGroups).to have_received(:generate) }
      it { expect(Reporting::Prohibitions).to have_received(:generate) }
      it { expect(Reporting::Differences).to have_received(:generate) }
      it { expect(ActionMailer::Base.deliveries.count).to eq(1) }
    end

    context 'when on the uk service and the day is not a monday' do
      let(:service) { 'uk' }
      let(:date) { '2023-10-31' }

      it { expect(Reporting::Commodities).to have_received(:generate) }
      it { expect(Reporting::Basic).to have_received(:generate) }
      it { expect(Reporting::SupplementaryUnits).to have_received(:generate) }
      it { expect(Reporting::DeclarableDuties).to have_received(:generate) }
      it { expect(Reporting::GeographicalAreaGroups).to have_received(:generate) }
      it { expect(Reporting::Prohibitions).to have_received(:generate) }
      it { expect(Reporting::Differences).not_to have_received(:generate) }
      it { expect(ActionMailer::Base.deliveries.count).to eq(0) }
    end
  end
end
