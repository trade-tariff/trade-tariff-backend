RSpec.describe BuildIndexByHeadingWorker, type: :worker do
  describe '#perform' do
    let!(:commodity) { create(:commodity, goods_nomenclature_item_id: '0101000001') }
    let(:index_name) { 'Search::BulkSearchIndex' }
    let(:heading_short_code) { '0101' }
    let(:opensearch_client) { instance_double(OpenSearch::Client) }

    before do
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
                _id: commodity.id,
                data: 'serialized_entry',
              },
            },
          ],
        )
    end
  end
end
