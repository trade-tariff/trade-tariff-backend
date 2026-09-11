RSpec.describe BuildIndexPageWorker, type: :worker do
  describe '#methods' do
    let :search_result_commodity_ids do
      search_result.dig('hits', 'hits')
                   .map { |h| h.dig('_source', 'goods_nomenclature_item_id') }
    end

    describe 'build index page' do
      before do
        # Make sure index is fresh
        TradeTariffBackend.search_client.drop_index(search_index)
        TradeTariffBackend.search_client.create_index(search_index)
        commodities # trigger creation of commodity

        described_class.new.perform 'search', search_index.name_without_namespace, 1

        TradeTariffBackend.opensearch_client.indices.refresh(index: search_index.name)
      end

      let(:commodities) do
        create_pair :commodity, :with_description, description: 'test description'
      end

      let(:search_index) { Search::CommodityIndex.new }

      let(:search_result) do
        TradeTariffBackend.search_client.search q: 'test', index: search_index.name
      end

      it 'has bulk indexed the expected commodity' do
        expect(search_result_commodity_ids).to \
          eq(commodities.map(&:goods_nomenclature_item_id))
      end
    end

    describe 'when the bulk response reports per item failures' do
      subject(:perform) { described_class.new.perform 'search', search_index.name_without_namespace, 1 }

      before do
        TradeTariffBackend.search_client.drop_index(search_index)
        TradeTariffBackend.search_client.create_index(search_index)
        create :commodity, :with_description, description: 'test description'

        allow(TradeTariffBackend.opensearch_client).to receive(:bulk).and_return(bulk_response)
      end

      let(:search_index) { Search::CommodityIndex.new }

      context 'when the failures are queue rejections' do
        let(:bulk_response) do
          {
            'errors' => true,
            'items' => [
              {
                'index' => {
                  '_index' => search_index.name,
                  '_id' => '101',
                  'status' => 429,
                  'error' => { 'type' => 'es_rejected_execution_exception', 'reason' => 'rejected execution' },
                },
              },
            ],
          }
        end

        it 'raises a rejection error carrying the index and page' do
          expect { perform }.to raise_error(
            TradeTariffBackend::BulkResponse::BulkRejectedError,
            /search\/CommodityIndex page 1.*es_rejected_execution_exception/m,
          )
        end
      end

      context 'when the failures are permanent' do
        let(:bulk_response) do
          {
            'errors' => true,
            'items' => [
              {
                'index' => {
                  '_index' => search_index.name,
                  '_id' => '101',
                  'status' => 400,
                  'error' => { 'type' => 'mapper_parsing_exception', 'reason' => 'failed to parse field' },
                },
              },
            ],
          }
        end

        it 'raises an indexing error carrying the failed document id' do
          expect { perform }.to raise_error(
            TradeTariffBackend::BulkResponse::BulkIndexingError,
            /mapper_parsing_exception.*101/m,
          )
        end
      end

      context 'when the bulk request itself raises' do
        let(:bulk_response) { nil }

        before do
          allow(TradeTariffBackend.opensearch_client).to receive(:bulk).and_raise(Faraday::ConnectionFailed, 'boom')
        end

        it 'still converts transport failures into an IndexingError' do
          expect { perform }.to raise_error(described_class::IndexingError, /Failed building index/)
        end
      end
    end

    describe 'build index page with old worker params' do
      before do
        # Make sure index is fresh
        TradeTariffBackend.search_client.drop_index(search_index)
        TradeTariffBackend.search_client.create_index(search_index)

        described_class.new.perform 'search', commodity.class.name, 1

        TradeTariffBackend.opensearch_client.indices.refresh(index: search_index.name)
      end

      let(:commodity) do
        create :commodity, :with_description, description: 'test description'
      end

      let(:search_index) { Search::CommodityIndex.new }

      let(:search_result) do
        TradeTariffBackend.search_client.search q: 'test', index: search_index.name
      end

      it 'has bulk indexed the expected commodity' do
        expect(search_result_commodity_ids.first).to eq commodity.goods_nomenclature_item_id
      end
    end
  end
end
