RSpec.describe BuildIndexByHeadingWorker, type: :worker do
  describe '#perform' do
    let(:index_name) { 'Search::BulkSearchIndex' }
    let(:heading_short_code) { '0101' }
    let(:opensearch_client) { instance_double(OpenSearch::Client) }

    before do
      create(:commodity, goods_nomenclature_item_id: '0101000001')
      allow(TradeTariffBackend).to receive(:opensearch_client).and_return(opensearch_client)
      allow(opensearch_client).to receive(:bulk)
    end

    it 'serializes and indexes the entries' do
      described_class.new.perform(index_name, heading_short_code)

      expect(opensearch_client)
        .to have_received(:bulk)
        .with(
          body: [
            {
              index: {
                _index: 'tariff-test-bulk_searches-uk',
                _id: '010100',
                data: {
                  'number_of_digits' => 6,
                  'short_code' => '010100',
                  'indexed_descriptions' => '',
                  'search_references' => '',
                  'intercept_terms' => '',
                },
              },
            },
            {
              index: {
                _index: 'tariff-test-bulk_searches-uk',
                _id: '01010000',
                data: {
                  'number_of_digits' => 8,
                  'short_code' => '01010000',
                  'indexed_descriptions' => '',
                  'search_references' => '',
                  'intercept_terms' => '',
                },
              },
            },
          ],
        )
    end
  end
end
