RSpec.describe Search::FailureCodes do
  describe '::ALL' do
    it 'contains the stable response codes' do
      expect(described_class::ALL).to eq(
        %w[
          query_expansion_failed
          embedding_generation_failed
          vector_retrieval_failed
          interactive_search_failed
          opensearch_failed
        ],
      )
    end
  end
end
