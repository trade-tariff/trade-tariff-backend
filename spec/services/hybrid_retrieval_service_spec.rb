RSpec.describe HybridRetrievalService do
  def make_result(sid:, item_id:, score:)
    OpenStruct.new(
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

  let(:opensearch_result) do
    OpensearchRetrievalService::Result.new(
      results: opensearch_results,
      expanded_query: 'expanded horses',
    )
  end

  before do
    allow(OpensearchRetrievalService).to receive(:call).and_return(opensearch_result)
    allow(VectorRetrievalService).to receive(:call).and_return(vector_results)
    allow(AdminConfiguration).to receive(:integer_value).and_call_original
    allow(AdminConfiguration).to receive(:integer_value).with('rrf_k').and_return(60)
    allow(Search::Instrumentation).to receive(:retrieval_leg_completed)
  end

  describe '#call' do
    it 'runs both retrieval legs inside TimeMachine.at(as_of)' do
      as_of = Time.zone.today
      allow(TimeMachine).to receive(:at).with(as_of).and_yield

      described_class.call(query: 'horses', as_of: as_of)

      expect(TimeMachine).to have_received(:at).with(as_of).at_least(:twice)
      expect(OpensearchRetrievalService).to have_received(:call).with(
        query: 'horses', as_of: as_of, request_id: nil, limit: 30,
      )
      expect(VectorRetrievalService).to have_received(:call).with(query: 'horses', limit: 30)
    end

    it 'returns items from both lists ranked by RRF score' do
      result = described_class.call(query: 'horses', as_of: Time.zone.today)

      sids = result.results.map(&:goods_nomenclature_sid)
      expect(sids).to include(1, 2, 3, 4)
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
      result = described_class.call(query: 'horses', as_of: Time.zone.today)

      expect(result.expanded_query).to eq('expanded horses')
    end

    it 'reads rrf_k from AdminConfiguration' do
      described_class.call(query: 'horses', as_of: Time.zone.today)

      expect(AdminConfiguration).to have_received(:integer_value).with('rrf_k')
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
          hash_including(leg: :opensearch, status: 'error'),
        )
        expect(Search::Instrumentation).to have_received(:retrieval_leg_completed).with(
          hash_including(leg: :vector, status: 'success'),
        )
      end
    end

    context 'when vector leg fails' do
      before do
        allow(VectorRetrievalService).to receive(:call).and_raise(StandardError, 'vector down')
      end

      it 'falls back to opensearch results' do
        result = described_class.call(query: 'horses', as_of: Time.zone.today)

        sids = result.results.map(&:goods_nomenclature_sid)
        expect(sids).to eq([1, 2, 3])
      end

      it 'still returns expanded_query from opensearch' do
        result = described_class.call(query: 'horses', as_of: Time.zone.today)

        expect(result.expanded_query).to eq('expanded horses')
      end

      it 'emits error status for vector leg' do
        described_class.call(query: 'horses', as_of: Time.zone.today)

        expect(Search::Instrumentation).to have_received(:retrieval_leg_completed).with(
          hash_including(leg: :opensearch, status: 'success'),
        )
        expect(Search::Instrumentation).to have_received(:retrieval_leg_completed).with(
          hash_including(leg: :vector, status: 'error'),
        )
      end
    end

    context 'when both legs fail' do
      before do
        allow(OpensearchRetrievalService).to receive(:call).and_raise(StandardError, 'opensearch down')
        allow(VectorRetrievalService).to receive(:call).and_raise(StandardError, 'vector down')
      end

      it 'returns empty results' do
        result = described_class.call(query: 'horses', as_of: Time.zone.today)

        expect(result.results).to be_empty
      end
    end
  end
end
