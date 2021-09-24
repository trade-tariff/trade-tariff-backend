RSpec.describe TradeTariffBackend do
  describe '.reindex' do
    context 'when successful' do
      let(:stub_indexer) { double(update: true) }

      before { described_class.reindex(stub_indexer) }

      it 'reindexes Tariff model contents in the search engine' do
        expect(stub_indexer).to have_received(:update)
      end
    end

    context 'when failed' do
      let(:mock_indexer) { double }

      before do
        expect(mock_indexer).to receive(:update).and_raise(StandardError)

        described_class.reindex(mock_indexer)
      end

      it 'notified system operator about indexing failure' do
        expect(ActionMailer::Base.deliveries).not_to be_empty
        email = ActionMailer::Base.deliveries.last
        expect(email.encoded).to match(/Backtrace/)
        expect(email.encoded).to match(/failed to reindex/)
      end
    end
  end

  describe '.platform' do
    context 'platform should be Rails.env' do
      it 'defaults to Rails.env' do
        expect(described_class.platform).to eq Rails.env
      end
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
