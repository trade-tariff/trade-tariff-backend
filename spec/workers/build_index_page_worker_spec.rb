RSpec.describe BuildIndexPageWorker, type: :worker do
  describe '#methods' do
    let :search_result_commodity_ids do
      search_result.hits
                   .hits
                   .map(&:_source)
                   .map(&:goods_nomenclature_item_id)
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
