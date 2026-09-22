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

  describe 'filter_prefixes' do
    before do
      allow(HybridRetrievalService).to receive(:call).and_return(
        HybridRetrievalService::Result.new(results: [], expanded_query: 'horses', source_results: []),
      )
    end

    it 'passes an array of prefixes to hybrid retrieval' do
      described_class.new(q: 'horses', filter_prefixes: %w[0101 6307]).call

      expect(HybridRetrievalService).to have_received(:call).with(
        hash_including(filter_prefixes: %w[0101 6307]),
      )
    end

    it 'accepts a comma separated string of prefixes' do
      described_class.new(q: 'horses', filter_prefixes: '0101, 6307').call

      expect(HybridRetrievalService).to have_received(:call).with(
        hash_including(filter_prefixes: %w[0101 6307]),
      )
    end

    it 'passes an empty array when the caller supplies none' do
      described_class.new(q: 'horses').call

      expect(HybridRetrievalService).to have_received(:call).with(
        hash_including(filter_prefixes: []),
      )
    end

    it 'removes duplicates and blanks' do
      described_class.new(q: 'horses', filter_prefixes: ['0101', '', '0101', ' 6307 ']).call

      expect(HybridRetrievalService).to have_received(:call).with(
        hash_including(filter_prefixes: %w[0101 6307]),
      )
    end

    it 'rejects a prefix that is not digits' do
      result = described_class.new(q: 'horses', filter_prefixes: %w[01AB]).call

      expect(result[:errors].first).to include(status: '422', title: 'Invalid filter_prefixes')
      expect(result[:errors].first[:detail]).to include('01AB')
      expect(HybridRetrievalService).not_to have_received(:call)
    end

    it 'rejects a prefix that is too short' do
      result = described_class.new(q: 'horses', filter_prefixes: %w[0]).call

      expect(result[:errors].first[:title]).to eq('Invalid filter_prefixes')
    end

    it 'rejects a prefix that is longer than a commodity code' do
      result = described_class.new(q: 'horses', filter_prefixes: %w[01012100001]).call

      expect(result[:errors].first[:title]).to eq('Invalid filter_prefixes')
    end

    it 'rejects more prefixes than the maximum' do
      prefixes = (1..11).map { |n| sprintf('%04d', n) }

      result = described_class.new(q: 'horses', filter_prefixes: prefixes).call

      expect(result[:errors].first[:detail]).to include('at most 10')
    end

    it 'rejects invalid prefixes before it runs an empty query' do
      result = described_class.new(q: '', filter_prefixes: %w[01AB]).call

      expect(result[:errors].first[:title]).to eq('Invalid filter_prefixes')
    end
  end

  describe 'search_non_declarables' do
    before do
      allow(HybridRetrievalService).to receive(:call).and_return(
        HybridRetrievalService::Result.new(results: [], expanded_query: 'horses', source_results: []),
      )
    end

    it 'passes nil when the caller does not ask, so the admin setting still decides' do
      described_class.new(q: 'horses').call

      expect(HybridRetrievalService).to have_received(:call).with(
        hash_including(search_non_declarables: nil),
      )
    end

    it 'passes true when the caller opts in' do
      described_class.new(q: 'horses', search_non_declarables: 'true').call

      expect(HybridRetrievalService).to have_received(:call).with(
        hash_including(search_non_declarables: true),
      )
    end

    it 'passes false when the caller opts out' do
      described_class.new(q: 'horses', search_non_declarables: 'false').call

      expect(HybridRetrievalService).to have_received(:call).with(
        hash_including(search_non_declarables: false),
      )
    end

    it 'accepts a real boolean' do
      described_class.new(q: 'horses', search_non_declarables: true).call

      expect(HybridRetrievalService).to have_received(:call).with(
        hash_including(search_non_declarables: true),
      )
    end

    it 'treats a blank value as not asked' do
      described_class.new(q: 'horses', search_non_declarables: '').call

      expect(HybridRetrievalService).to have_received(:call).with(
        hash_including(search_non_declarables: nil),
      )
    end
  end

  describe 'limit' do
    def make_result(sid:, score:)
      GoodsNomenclatureResult.new(
        id: sid,
        goods_nomenclature_item_id: sprintf('01012%05d', sid),
        goods_nomenclature_sid: sid,
        producline_suffix: '80',
        goods_nomenclature_class: 'Commodity',
        description: "item #{sid}",
        formatted_description: "Item #{sid}",
        self_text: nil,
        classification_description: "Item #{sid}",
        full_description: "Item #{sid}",
        heading_description: nil,
        declarable: true,
        score: score,
        confidence: nil,
      )
    end

    # Hybrid retrieval fuses two legs of up to `limit` items each, so it can
    # return twice the limit the caller asked for. This service caps its own
    # response. The fused set stays whole for guided search, which uses the
    # same retrieval service and needs every candidate.
    let(:fused_results) { (1..60).map { |sid| make_result(sid: sid, score: (100 - sid) / 100.0) } }

    before do
      allow(HybridRetrievalService).to receive(:call).and_return(
        HybridRetrievalService::Result.new(results: fused_results, expanded_query: 'horses', source_results: fused_results),
      )
    end

    it 'caps the response at the requested limit' do
      response = described_class.new(q: 'horses', limit: 10).call

      expect(response[:data].size).to eq(10)
    end

    it 'keeps the highest scoring results when it caps' do
      response = described_class.new(q: 'horses', limit: 10).call

      sids = response[:data].map { |record| record[:attributes][:goods_nomenclature_sid] }
      expect(sids).to eq((1..10).to_a)
    end

    it 'reports the capped count and the capped max score in the meta' do
      response = described_class.new(q: 'horses', limit: 10).call

      expect(response[:meta][:result_count]).to eq(10)
      expect(response[:meta][:max_score]).to eq(0.99)
    end

    it 'still asks retrieval for the full per leg limit' do
      described_class.new(q: 'horses', limit: 10).call

      expect(HybridRetrievalService).to have_received(:call).with(
        hash_including(limit: 10),
      )
    end
  end
end
