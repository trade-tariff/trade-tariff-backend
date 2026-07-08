RSpec.describe TradeTariffBackend::SearchClient do
  describe '.server_namespace' do
    subject { described_class.server_namespace }

    it { is_expected.to eql ['tariff-test', ENV['TEST_ENV_NUMBER']].compact_blank.join('-') }

    context 'when overridden' do
      before do
        orig_namespace # trigger caching in method
        described_class.server_namespace = 'overridden'
      end

      after { described_class.server_namespace = orig_namespace }

      let(:orig_namespace) { described_class.server_namespace }

      it { is_expected.to eql 'overridden' }
    end
  end

  describe '.search_operation_options' do
    subject { described_class.search_operation_options }

    it { is_expected.to be_instance_of Hash }
  end

  describe '#search' do
    let(:commodity) do
      create(:commodity, :with_description, description: 'test description').tap do |model|
        index_model(model)
      end
    end

    let(:index) { Search::CommodityIndex.new }

    let(:search_result) do
      TradeTariffBackend.search_client.search q: 'test', index: index.name
    end

    let(:search_result_commodity_ids) do
      search_result.dig('hits', 'hits').map { |h| h.dig('_source', 'goods_nomenclature_item_id') }
    end

    context 'with existing index' do
      before { commodity }

      it 'searches in supplied index' do
        expect(search_result.dig('hits', 'total', 'value')).to be >= 1
      end

      it 'returns expected results' do
        expect(search_result_commodity_ids).to include commodity.goods_nomenclature_item_id
      end

      it 'returns results wrapped in a SearchResponse' do
        expect(search_result).to be_a TradeTariffBackend::SearchResponse
      end
    end
  end

  describe '#reindex' do
    let(:indices) { instance_double(OpenSearch::API::Indices::IndicesClient) }
    let(:opensearch_client) { instance_double(OpenSearch::Client, indices:) }
    let(:search_client) { described_class.new(opensearch_client) }
    let(:index_class) do
      Class.new do
        def name = 'tariff-test-index-uk'
        def name_without_namespace = 'TestIndex'
        def definition = { mappings: { properties: {} } }
        def total_pages = 2
      end
    end

    before do
      allow(indices).to receive(:exists).with(index: 'tariff-test-index-uk').and_return(false)
      allow(indices).to receive(:create)
      allow(BuildIndexPageWorker).to receive(:perform_async)
    end

    it 'accepts an index class and reindexes using an index instance' do
      search_client.reindex(index_class)

      expect(indices).to have_received(:create).with(index: 'tariff-test-index-uk', body: { mappings: { properties: {} } })
      expect(BuildIndexPageWorker).to have_received(:perform_async).with('search', 'TestIndex', 1)
      expect(BuildIndexPageWorker).to have_received(:perform_async).with('search', 'TestIndex', 2)
    end
  end
end
