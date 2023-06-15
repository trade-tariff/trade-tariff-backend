RSpec.describe BulkSearchService do
  subject(:service) { described_class.new(id) }

  context 'when there is a corresponding result collection in a queued state' do
    let(:id) { BulkSearch::ResultCollection.enqueue(searches).id }

    let(:searches) do
      [
        { attributes: { input_description: 'red herring' } },
        { attributes: { input_description: 'white bait' } },
      ]
    end

    before do
      allow(TradeTariffBackend.v2_search_client).to receive(:msearch).and_call_original
    end

    it { expect(service.call).to be_a(BulkSearch::ResultCollection) }
    it { expect(service.call.status).to eq('completed') }

    it 'calls the search client' do
      service.call
      expect(TradeTariffBackend.v2_search_client).to have_received(:msearch).with(
        index: 'tariff-test-goods_nomenclatures-uk',
        body: [
          {},
          { query: { bool: { must: { query_string: { query: 'red herring', escape: true } } } }, size: 200 },
          {},
          { query: { bool: { must: { query_string: { query: 'white bait', escape: true } } } }, size: 200 },
        ],
      )
    end
  end

  context 'when there is `no` corresponding result collection in a queued state' do
    let(:id) { SecureRandom.uuid }

    it { expect(service.call).to be_nil }
  end
end
