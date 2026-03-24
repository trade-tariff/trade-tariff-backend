RSpec.describe TradeTariffBackend::Clients do
  subject(:backend) { TradeTariffBackend }

  # Reset memoized clients between examples
  after do
    backend.instance_variable_set(:@redis, nil)
    backend.instance_variable_set(:@frontend_redis, nil)
    backend.instance_variable_set(:@opensearch_client, nil)
    backend.instance_variable_set(:@search_client, nil)
    backend.instance_variable_set(:@ai_client, nil)
    backend.instance_variable_set(:@number_formatter, nil)
  end

  describe '.redis' do
    it 'returns a Redis instance' do
      expect(backend.redis).to be_a(Redis)
    end

    it 'memoizes the instance' do
      first = backend.redis
      expect(backend.redis).to be(first)
    end
  end

  describe '.frontend_redis' do
    it 'returns a Redis instance' do
      expect(backend.frontend_redis).to be_a(Redis)
    end

    it 'memoizes the instance' do
      first = backend.frontend_redis
      expect(backend.frontend_redis).to be(first)
    end
  end

  describe '.opensearch_client' do
    it 'returns an OpenSearch::Client' do
      expect(backend.opensearch_client).to be_a(OpenSearch::Client)
    end

    it 'memoizes the instance' do
      first = backend.opensearch_client
      expect(backend.opensearch_client).to be(first)
    end
  end

  describe '.search_client' do
    it 'returns a SearchClient' do
      expect(backend.search_client).to be_a(TradeTariffBackend::SearchClient)
    end

    it 'memoizes the instance' do
      first = backend.search_client
      expect(backend.search_client).to be(first)
    end
  end

  describe '.search_indexes' do
    it 'returns an array of search index instances' do
      indexes = backend.search_indexes
      expect(indexes).to all(respond_to(:name))
    end

    it 'includes all expected index types' do
      index_classes = backend.search_indexes.map(&:class)
      expect(index_classes).to include(
        Search::ChapterIndex,
        Search::CommodityIndex,
        Search::HeadingIndex,
        Search::SearchReferenceIndex,
        Search::SearchSuggestionsIndex,
        Search::GoodsNomenclatureIndex,
      )
    end
  end

  describe '.number_formatter' do
    it 'returns a NumberFormatter instance' do
      expect(backend.number_formatter).to be_a(TradeTariffBackend::NumberFormatter)
    end

    it 'memoizes the instance' do
      first = backend.number_formatter
      expect(backend.number_formatter).to be(first)
    end
  end
end
