RSpec.describe TradeTariffBackend do
  describe '.reindex_all' do
    let(:indexer) { double }

    context 'when successful' do
      before do
        allow(indexer).to receive(:update_all).and_return(true)

        described_class.reindex(indexer)
      end

      it { expect(indexer).to have_received(:update_all) }
    end

    context 'when failed' do
      before do
        allow(indexer).to receive(:update_all).and_raise(StandardError)

        described_class.reindex(indexer)
      end

      it { expect(ActionMailer::Base.deliveries.last.encoded).to match(/failed to reindex/) }
    end
  end

  describe '.currency' do
    before do
      allow(described_class).to receive(:service).and_return(choice)
    end

    context 'when the service is xi' do
      let(:choice) { 'xi' }

      it 'returns the correct currency' do
        expect(described_class.currency).to eq('EUR')
      end
    end

    context 'when the service is uk' do
      let(:choice) { 'uk' }

      it 'returns the correct currency' do
        expect(described_class.currency).to eq('GBP')
      end
    end

    context 'when the service is not set' do
      let(:choice) { nil }

      it 'returns the correct currency' do
        expect(described_class.currency).to eq('GBP')
      end
    end
  end
end
