require 'rails_helper'

RSpec.describe BulkSearch do
  describe '.enqueue' do
    let(:searches) do
      [
        { input_description: 'red herring' },
        { input_description: 'white bait' },
      ]
    end

    it 'enqueues a bulk search job' do
      allow(BulkSearchWorker).to receive(:perform_async)
      described_class.enqueue(searches)
      expect(BulkSearchWorker).to have_received(:perform_async).with(match(/^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$/))
    end

    it 'compresses the result collection' do
      allow(Zlib::Deflate).to receive(:deflate).and_call_original
      described_class.enqueue(searches)
      expect(Zlib::Deflate).to have_received(:deflate).with(match(/^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$/))
    end

    it 'stores the compressed result collection' do
      allow(TradeTariffBackend.redis).to receive(:set)
      described_class.enqueue(searches)
      expect(TradeTariffBackend.redis).to have_received(:set).with(match(/^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$/), anything, ex: 7200)
    end

    it 'returns a bulk search result collection' do
      expect(described_class.enqueue(searches)).to be_a(BulkSearch::ResultCollection)
    end
  end

  describe '.find' do
    let(:id) { SecureRandom.uuid }
    let(:json_blob) do
      {
        id:,
        status:,
        searches: [],
      }.to_json
    end

    context 'when the bulk search job exists' do
      before do
        TradeTariffBackend.redis.set(id, Zlib::Deflate.deflate(json_blob))

        allow(TradeTariffBackend.redis).to receive(:get).and_call_original
      end

      let(:status) { BulkSearch::COMPLETE_STATE }

      it 'returns a bulk search result collection' do
        expect(described_class.find(id)).to be_a(BulkSearch::ResultCollection)
      end

      it 'fetches the compressed result collection' do
        described_class.find(id)
        expect(TradeTariffBackend.redis).to have_received(:get).with(id)
      end
    end

    context 'when the bulk search job does not exist' do
      let(:json_blob) { nil }

      it 'returns a bulk search result collection' do
        expect(described_class.find(id)).to be_a(BulkSearch::ResultCollection)
      end

      it 'sets the status to not found' do
        expect(described_class.find(id).status).to eq(BulkSearch::NOT_FOUND_STATE)
      end
    end
  end
end
