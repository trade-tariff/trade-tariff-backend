RSpec.describe HybridRetrievalService do
  def make_result(sid:, item_id:, score:)
    GoodsNomenclatureResult.new(
      id: sid,
      goods_nomenclature_item_id: item_id,
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

  let(:opensearch_results) do
    [
      make_result(sid: 1, item_id: '0101210000', score: 12.5),
      make_result(sid: 2, item_id: '0101220000', score: 10.0),
      make_result(sid: 3, item_id: '0101230000', score: 8.0),
    ]
  end

  let(:vector_results) do
    [
      make_result(sid: 2, item_id: '0101220000', score: 0.95),
      make_result(sid: 4, item_id: '0101240000', score: 0.90),
      make_result(sid: 1, item_id: '0101210000', score: 0.85),
    ]
  end

  let(:vector_diagnostics) do
    VectorRetrievalService::Result.new(results: vector_results, max_score: 0.31)
  end

  let(:expanded_query) { 'expanded horses' }

  let(:opensearch_result) do
    OpensearchRetrievalService::Result.new(
      results: opensearch_results,
      expanded_query: expanded_query,
    )
  end

  before do
    allow(OpensearchRetrievalService).to receive(:call).and_return(opensearch_result)
    allow(VectorRetrievalService).to receive(:call_with_diagnostics).and_return(vector_diagnostics)
    allow(AdminConfiguration).to receive(:enabled?).and_call_original
    allow(AdminConfiguration).to receive(:enabled?).with('hybrid_query_guardrail_enabled').and_return(false)
    allow(AdminConfiguration).to receive(:integer_value).and_call_original
    allow(AdminConfiguration).to receive(:integer_value).with('rrf_k').and_return(60)
    allow(AdminConfiguration).to receive(:integer_value).with('hybrid_query_guardrail_threshold').and_return(32)
    allow(Search::Instrumentation).to receive(:retrieval_leg_completed)
    allow(Search::Instrumentation).to receive(:retrieval_results_returned)
    allow(Search::Instrumentation).to receive(:query_guardrail_decided)
  end

  describe '#call' do
    it 'runs both retrieval legs inside TimeMachine.at(as_of)' do
      as_of = Time.zone.today
      allow(TimeMachine).to receive(:at).with(as_of).and_yield

      described_class.call(query: 'horses', expanded_query: expanded_query, as_of: as_of)

      expect(TimeMachine).to have_received(:at).with(as_of).at_least(:twice)
      expect(OpensearchRetrievalService).to have_received(:call).with(
        query: 'horses', expanded_query: expanded_query, as_of: as_of, request_id: nil, limit: 30,
      )
      expect(VectorRetrievalService).to have_received(:call_with_diagnostics).with(
        query: expanded_query, limit: 30, request_id: nil,
      )
    end

    it 'passes filter prefixes to both retrieval legs' do
      as_of = Time.zone.today

      described_class.call(query: 'horses', expanded_query: expanded_query, as_of: as_of, filter_prefixes: %w[0101])

      expect(OpensearchRetrievalService).to have_received(:call).with(
        query: 'horses', expanded_query: expanded_query,
        as_of: as_of, request_id: nil, limit: 30, filter_prefixes: %w[0101]
      )
      expect(VectorRetrievalService).to have_received(:call_with_diagnostics).with(
        query: expanded_query, limit: 30, filter_prefixes: %w[0101], request_id: nil,
      )
    end

    it 'returns items from both lists ranked by RRF score' do
      result = described_class.call(query: 'horses', as_of: Time.zone.today)

      sids = result.results.map(&:goods_nomenclature_sid)
      expect(sids).to include(1, 2, 3, 4)
    end

    it 'returns source results for diagnostics decisions' do
      result = described_class.call(query: 'horses', as_of: Time.zone.today)

      expect(result.source_results).to match_array(opensearch_results + vector_results)
    end

    it 'ranks items in both lists higher than items in only one list' do
      result = described_class.call(query: 'horses', as_of: Time.zone.today)

      sids = result.results.map(&:goods_nomenclature_sid)
      # SIDs 1 and 2 appear in both lists, so they should rank above 3 and 4
      shared_positions = [sids.index(1), sids.index(2)]
      single_positions = [sids.index(3), sids.index(4)]
      expect(shared_positions.max).to be < single_positions.min
    end

    it 'deduplicates by goods_nomenclature_sid' do
      result = described_class.call(query: 'horses', as_of: Time.zone.today)

      sids = result.results.map(&:goods_nomenclature_sid)
      expect(sids).to eq(sids.uniq)
    end

    it 'returns expanded_query from the opensearch leg' do
      result = described_class.call(query: 'horses', expanded_query: expanded_query, as_of: Time.zone.today)

      expect(result.expanded_query).to eq(expanded_query)
    end

    it 'attributes guardrail telemetry to the calling search journey' do
      described_class.call(query: 'horses', as_of: Time.zone.today, search_type: 'classification')

      expect(Search::Instrumentation).to have_received(:query_guardrail_decided).with(
        hash_including(search_type: 'classification'),
      )
    end

    it 'emits an attributable control decision with the configured threshold' do
      described_class.call(
        query: 'horses', expanded_query: expanded_query, as_of: Time.zone.today,
        request_id: 'req-1', iteration: 2
      )

      expect(Search::Instrumentation).to have_received(:query_guardrail_decided).with(
        request_id: 'req-1',
        search_type: 'interactive',
        query: 'horses',
        effective_query: expanded_query,
        iteration: 2,
        enabled: false,
        accepted: true,
        max_score: 0.31,
        threshold: 0.32,
        reason: 'disabled',
      )
    end

    it 'reads rrf_k from AdminConfiguration' do
      described_class.call(query: 'horses', as_of: Time.zone.today)

      expect(AdminConfiguration).to have_received(:integer_value).with('rrf_k')
    end

    context 'when the hybrid query guardrail is enabled' do
      before do
        allow(AdminConfiguration).to receive(:enabled?).with('hybrid_query_guardrail_enabled').and_return(true)
      end

      it 'returns no suggestions when the raw vector score is below the configured threshold' do
        result = described_class.call(
          query: 'book a dentist appointment', expanded_query: expanded_query, as_of: Time.zone.today,
        )

        expect(result.results).to be_empty
        expect(Search::Instrumentation).to have_received(:query_guardrail_decided).with(
          request_id: nil,
          search_type: 'interactive',
          query: 'book a dentist appointment',
          effective_query: 'expanded horses',
          iteration: nil,
          enabled: true,
          accepted: false,
          max_score: 0.31,
          threshold: 0.32,
          reason: 'below_threshold',
        )
        expect(AdminConfiguration).not_to have_received(:integer_value).with('rrf_k')
      end

      it 'returns the merged suggestions when the raw vector score meets the configured threshold' do
        allow(VectorRetrievalService).to receive(:call_with_diagnostics).and_return(
          VectorRetrievalService::Result.new(results: vector_results, max_score: 0.32),
        )

        result = described_class.call(query: 'horses', as_of: Time.zone.today)

        expect(result.results).not_to be_empty
        expect(Search::Instrumentation).to have_received(:query_guardrail_decided).with(
          hash_including(accepted: true, max_score: 0.32, threshold: 0.32, reason: 'accepted'),
        )
      end

      it 'falls back to the default threshold if persisted configuration is out of range' do
        allow(AdminConfiguration).to receive(:integer_value).with('hybrid_query_guardrail_threshold').and_return(101)

        described_class.call(query: 'horses', as_of: Time.zone.today)

        expect(Search::Instrumentation).to have_received(:query_guardrail_decided).with(
          hash_including(accepted: false, threshold: 0.32, reason: 'below_threshold'),
        )
      end

      it 'distinguishes no eligible vector candidates from a low score' do
        allow(VectorRetrievalService).to receive(:call_with_diagnostics).and_return(
          VectorRetrievalService::Result.new(results: [], max_score: nil),
        )

        result = described_class.call(query: 'book a dentist appointment', as_of: Time.zone.today)

        expect(result.results).to be_empty
        expect(Search::Instrumentation).to have_received(:query_guardrail_decided).with(
          hash_including(accepted: false, max_score: nil, reason: 'no_vector_candidates'),
        )
      end

      it 'fails closed when the vector score needed by the guardrail is unavailable' do
        allow(VectorRetrievalService).to receive(:call_with_diagnostics).and_raise(StandardError, 'vector down')

        result = described_class.call(query: 'horses', as_of: Time.zone.today)

        expect(result.results).to be_empty
        expect(Search::Instrumentation).to have_received(:query_guardrail_decided).with(
          hash_including(accepted: false, max_score: nil, reason: 'vector_unavailable'),
        )
      end
    end

    it 'emits retrieval_leg_completed for both legs' do
      described_class.call(query: 'horses', as_of: Time.zone.today)

      expect(Search::Instrumentation).to have_received(:retrieval_leg_completed).with(
        hash_including(leg: :opensearch, status: 'success', result_count: 3),
      )
      expect(Search::Instrumentation).to have_received(:retrieval_leg_completed).with(
        hash_including(leg: :vector, status: 'success', result_count: 3),
      )
    end

    it 'emits retrieval results before and after RRF' do
      described_class.call(query: 'horses', as_of: Time.zone.today, request_id: 'req-1')

      expect(Search::Instrumentation).to have_received(:retrieval_results_returned).with(
        hash_including(request_id: 'req-1', retrieval_method: 'hybrid', stage: 'before_rrf', leg: :opensearch, results: opensearch_results),
      )
      expect(Search::Instrumentation).to have_received(:retrieval_results_returned).with(
        hash_including(request_id: 'req-1', retrieval_method: 'hybrid', stage: 'before_rrf', leg: :vector, results: vector_results),
      )
      expect(Search::Instrumentation).to have_received(:retrieval_results_returned).with(
        hash_including(request_id: 'req-1', retrieval_method: 'hybrid', stage: 'after_rrf'),
      )
    end

    context 'when opensearch leg fails' do
      before do
        allow(OpensearchRetrievalService).to receive(:call).and_raise(StandardError, 'opensearch down')
      end

      it 'falls back to vector results' do
        result = described_class.call(query: 'horses', as_of: Time.zone.today)

        sids = result.results.map(&:goods_nomenclature_sid)
        expect(sids).to eq([2, 4, 1])
      end

      it 'emits error status for opensearch leg' do
        described_class.call(query: 'horses', as_of: Time.zone.today)

        expect(Search::Instrumentation).to have_received(:retrieval_leg_completed).with(
          hash_including(leg: :opensearch, status: 'error', error_message: 'opensearch down'),
        )
        expect(Search::Instrumentation).to have_received(:retrieval_leg_completed).with(
          hash_including(leg: :vector, status: 'success'),
        )
      end
    end

    context 'when vector leg fails' do
      before do
        allow(VectorRetrievalService).to receive(:call_with_diagnostics).and_raise(StandardError, 'vector down')
      end

      it 'falls back to opensearch results' do
        result = described_class.call(query: 'horses', as_of: Time.zone.today)

        sids = result.results.map(&:goods_nomenclature_sid)
        expect(sids).to eq([1, 2, 3])
      end

      it 'still returns the expanded_query passed by internal search' do
        result = described_class.call(query: 'horses', expanded_query: expanded_query, as_of: Time.zone.today)

        expect(result.expanded_query).to eq(expanded_query)
      end

      it 'emits error status for vector leg' do
        described_class.call(query: 'horses', as_of: Time.zone.today)

        expect(Search::Instrumentation).to have_received(:retrieval_leg_completed).with(
          hash_including(leg: :opensearch, status: 'success'),
        )
        expect(Search::Instrumentation).to have_received(:retrieval_leg_completed).with(
          hash_including(leg: :vector, status: 'error', error_message: 'vector down'),
        )
      end
    end

    context 'when both legs fail' do
      before do
        allow(OpensearchRetrievalService).to receive(:call).and_raise(StandardError, 'opensearch down')
        allow(VectorRetrievalService).to receive(:call_with_diagnostics).and_raise(StandardError, 'vector down')
      end

      it 'raises a retrieval failure' do
        expect {
          described_class.call(query: 'horses', as_of: Time.zone.today)
        }.to raise_error(described_class::AllLegsFailed, 'Hybrid retrieval failed for all legs: opensearch down; vector down')
      end

      it 'emits error status for both legs' do
        expect {
          described_class.call(query: 'horses', as_of: Time.zone.today)
        }.to raise_error(described_class::AllLegsFailed)

        expect(Search::Instrumentation).to have_received(:retrieval_leg_completed).with(
          hash_including(leg: :opensearch, status: 'error', error_message: 'opensearch down'),
        )
        expect(Search::Instrumentation).to have_received(:retrieval_leg_completed).with(
          hash_including(leg: :vector, status: 'error', error_message: 'vector down'),
        )
      end
    end
  end
end
