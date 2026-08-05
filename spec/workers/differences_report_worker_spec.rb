RSpec.describe DifferencesReportWorker, type: :worker do
  subject(:worker) { described_class.new }

  describe 'sidekiq configuration' do
    it 'retries twice' do
      expect(described_class.get_sidekiq_options['retry']).to eq(2)
    end

    it 'waits an hour between retries so late report publications can appear' do
      expect(described_class.sidekiq_retry_in_block.call(0, nil)).to eq(1.hour.to_i)
    end
  end

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
