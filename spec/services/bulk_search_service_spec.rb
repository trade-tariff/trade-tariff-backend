RSpec.describe BulkSearchService do
  subject(:service) { described_class.new(id) }

  let(:id) { BulkSearch::ResultCollection.enqueue(searches).id }

  let(:searches) do
    [
      { attributes: { input_description: 'red herring' } },
      { attributes: { input_description: 'white bait' } },
    ]
  end

  before do
    allow(TradeTariffBackend.by_heading_search_client).to receive(:msearch).and_call_original
  end

  it { expect(service.call).to be_a(BulkSearch::ResultCollection) }
  it { expect(service.call.status).to eq('completed') }

  it 'calls the search client' do
    service.call
    expect(TradeTariffBackend.by_heading_search_client).to have_received(:msearch).with(
      index: 'tariff-test-bulk_searches-uk',
      body: [
        {},
        {
          query: {
            bool: {
              must: { query_string: { query: 'red herring', escape: true } },
              filter: { term: { number_of_digits: 6 } },
            },
          },
          size: 100,
        },
        {},
        {
          query: {
            bool: {
              must: { query_string: { query: 'white bait', escape: true } },
              filter: { term: { number_of_digits: 6 } },
            },
          },
          size: 100,
        },
      ],
    )
  end
end
