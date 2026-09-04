RSpec.describe Api::V2::ClassificationSearchService do
  after { TradeTariffRequest.search_failures = nil }

  describe '#call' do
    it 'always returns the search failures array for an empty query' do
      result = described_class.new(q: '', request_id: 'request-1').call

      expect(result.dig(:meta, :search_failures)).to eq([])
    end

    it 'returns stable retrieval failures recorded by hybrid search' do
      result = instance_double(
        HybridRetrievalService::Result,
        results: [],
        expanded_query: 'horses',
      )
      allow(HybridRetrievalService).to receive(:call) do
        TradeTariffRequest.record_search_failure(Search::FailureCodes::OPENSEARCH_FAILED)
        result
      end

      response = described_class.new(q: 'horses', request_id: 'request-1').call

      expect(response.dig(:meta, :search_failures)).to eq(%w[opensearch_failed])
    end
  end
end
