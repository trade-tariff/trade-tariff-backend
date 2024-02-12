RSpec.describe DifferencesReportWorker, type: :worker do
  subject(:worker) { described_class.new }

  describe '#perform' do
    before do
      allow(Reporting::Differences).to receive(:generate).and_return(differences)
    end

    let(:differences) { Reporting::Differences.new }

    context 'when delivering email' do
      before { worker.perform }

      it { expect(Reporting::Differences).to have_received(:generate) }
      it { expect(ActionMailer::Base.deliveries.count).to eq(1) }
    end

    context 'when not delivering email' do
      before { worker.perform(false) }

      it { expect(Reporting::Differences).to have_received(:generate) }
      it { expect(ActionMailer::Base.deliveries.count).to eq(0) }
    end
  end
end
