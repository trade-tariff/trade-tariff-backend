RSpec.describe BuildIndexPageWorker, type: :worker do
  describe '#methods' do
    describe 'build index page' do
      let(:commodity) do
        create :commodity, :with_description, description: 'test description'
      end

      before do
        # Make sure index is fresh
        TradeTariffBackend.search_client.drop_index(TradeTariffBackend.search_index_for('search', commodity))
        TradeTariffBackend.search_client.create_index(TradeTariffBackend.search_index_for('search', commodity))
      end

      it 'bulk indexes all model entries' do
        BuildIndexPageWorker.new.perform(
          'search',
          commodity.class.name,
          1,
          10,
        )
        sleep 2

        search_result = TradeTariffBackend.search_client.search q: 'test', index: TradeTariffBackend.search_index_for('search', commodity).name

        expect(search_result.hits.total.value).to be >= 1
        expect(search_result.hits.hits.first._source.goods_nomenclature_item_id).to eq commodity.goods_nomenclature_item_id
      end
    end
  end
end
