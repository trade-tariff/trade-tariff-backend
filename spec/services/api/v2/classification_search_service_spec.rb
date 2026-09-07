RSpec.describe Api::V2::ClassificationSearchService do
  after { TradeTariffRequest.search_failures = nil }

  let(:events) { [] }

  around do |example|
    subscriber = ActiveSupport::Notifications.subscribe(/\A(?:search_started|search_completed|search_failed)\.search\z/) do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end
    example.run
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  describe '#call' do
    it 'completes a healthy empty retrieval' do
      allow(HybridRetrievalService).to receive(:call).and_return(
        HybridRetrievalService::Result.new(results: [], expanded_query: 'horses', source_results: []),
      )

      described_class.new(q: 'horses', request_id: 'request-1').call

      expect(events.map(&:name)).to eq(%w[search_started.search search_completed.search])
      expect(events.last.payload).to include(
        request_id: 'request-1', search_type: 'classification', result_count: 0, results_type: 'hybrid', search_degraded: false,
      )
    end

    it 'emits one terminal retrieval failure' do
      allow(HybridRetrievalService).to receive(:call) do
        TradeTariffRequest.record_search_failure(Search::FailureCodes::OPENSEARCH_FAILED)
        TradeTariffRequest.record_search_failure(Search::FailureCodes::VECTOR_RETRIEVAL_FAILED)
        raise HybridRetrievalService::AllLegsFailed, 'all legs failed'
      end

      expect { described_class.new(q: 'horses', request_id: 'request-1').call }.to raise_error(HybridRetrievalService::AllLegsFailed)

      expect(events.map(&:name)).to eq(%w[search_started.search search_failed.search])
      expect(events.last.payload).to include(
        request_id: 'request-1', search_type: 'classification', search_degraded: true,
        opensearch_failed: true, vector_retrieval_failed: true, error_type: 'HybridRetrievalService::AllLegsFailed'
      )
    end

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
      expect(events.last).to have_attributes(
        name: 'search_completed.search',
        payload: hash_including(search_type: 'classification', search_degraded: true, opensearch_failed: true),
      )
    end
  end
end
