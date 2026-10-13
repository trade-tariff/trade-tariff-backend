require 'rails_helper'

RSpec.describe EvaluationQueuedSearchWorker, type: :worker do
  subject(:worker) { described_class.new }

  let(:inputs) { { q: 'horses', as_of: nil, request_id: 'eval-request-id', answers: [], configuration_overrides: {}, search_type: 'evaluation' } }
  let(:context) { { request_id: 'eval-request-id', request_source: 'backend_only', as_of: Time.zone.today.iso8601 } }
  let(:search) { QueuedSearch.create(params: inputs, context:) }

  after { search.delete }

  before do
    # Force the opensearch-only retrieval path (mirrors spec/requests/api/internal/search_controller_spec.rb
    # and this worker's predecessor, the old synchronous SearchesController spec) so a real
    # Api::Internal::SearchService call doesn't fall into hybrid/vector retrieval, which would
    # hit the live embeddings API and fail under WebMock.
    allow(AdminConfiguration).to receive(:option_value).and_call_original
    allow(AdminConfiguration).to receive(:option_value).with('retrieval_method').and_return('opensearch')
    allow(AdminConfiguration).to receive(:enabled?).and_call_original
    allow(AdminConfiguration).to receive(:enabled?).with('expand_search_when_needed_enabled').and_return(false)
    allow(ExpandSearchQueryService).to receive(:call).and_wrap_original do |_method, query|
      ExpandSearchQueryService::Result.new(expanded_query: query, reason: nil)
    end
  end

  describe '#perform' do
    context 'with a blank query' do
      let(:inputs) { { q: '', as_of: nil, request_id: 'eval-request-id', answers: [], configuration_overrides: {}, search_type: 'evaluation' } }

      it 'stores the search result' do
        worker.perform(search.id)

        expect(search.payload).to include(
          'status' => 'completed', 'response_status' => 200,
          'result' => { 'data' => [], 'meta' => { 'search_failures' => [] } }
        )
      end
    end

    context 'with a disallowed configuration_overrides key' do
      # AllowlistValidator runs synchronously in the controller before a search is ever queued
      # (AI-1438) -- a worker only ever sees overrides that already passed it. This proves the
      # worker itself doesn't re-validate (and doesn't need to), by passing the service's own
      # configuration_overrides straight through regardless of content.
      let(:inputs) { { q: 'horses', as_of: nil, request_id: 'eval-request-id', answers: [], configuration_overrides: { candidate_limit: 5 }, search_type: 'evaluation' } }

      before { allow(Api::Internal::SearchService).to receive(:new).and_call_original }

      it 'passes configuration_overrides through to Api::Internal::SearchService' do
        worker.perform(search.id)

        expect(Api::Internal::SearchService).to have_received(:new).with(
          hash_including('configuration_overrides' => hash_including('candidate_limit' => 5)),
        )
      end
    end

    context 'without any configuration_overrides' do
      before { allow(Api::Internal::SearchService).to receive(:new).and_call_original }

      it 'still calls Api::Internal::SearchService, with an empty configuration_overrides' do
        worker.perform(search.id)

        expect(Api::Internal::SearchService).to have_received(:new).with(
          hash_including('configuration_overrides' => {}),
        )
      end

      it "tags the call with search_type: 'evaluation'" do
        worker.perform(search.id)

        expect(Api::Internal::SearchService).to have_received(:new).with(
          hash_including('search_type' => 'evaluation'),
        )
      end
    end

    context 'when a real interactive search LLM call happens' do
      let(:inputs) { { q: 'trainers', as_of: nil, request_id: 'eval-request-id', answers: [], configuration_overrides: {}, search_type: 'evaluation' } }
      let(:usage) { { 'prompt_tokens' => 120, 'completion_tokens' => 40, 'total_tokens' => 160 } }
      let(:ai_response) do
        AiUsage.attach_metadata(
          '{"answers": [{"commodity_code": "6404110000", "confidence": "strong"}]}',
          AiUsage.metadata_for(model: 'gpt-5.2', event_kind: 'interactive_search', usage:),
        )
      end

      before do
        # Index TWO real documents so opensearch_results.size > 1 and InteractiveSearchService
        # doesn't take the single_result? short circuit (which makes no LLM call at all, and so
        # would make this test pass for the wrong reason). Same real-indexing pattern
        # spec/requests/api/internal/search_controller_spec.rb already uses.
        index = Search::GoodsNomenclatureIndex.new
        [
          { sid: 98_001, item_id: '6404110000', description: 'trainers with rubber sole' },
          { sid: 98_002, item_id: '6404190000', description: 'trainers with textile upper' },
        ].each do |doc|
          TradeTariffBackend.search_client.index_by_name(
            index.name,
            doc[:sid],
            {
              goods_nomenclature_sid: doc[:sid],
              goods_nomenclature_item_id: doc[:item_id],
              producline_suffix: '80',
              goods_nomenclature_class: 'Commodity',
              description: doc[:description],
              formatted_description: doc[:description],
              full_description: doc[:description],
              heading_description: 'Footwear',
              declarable: true,
              validity_start_date: Time.zone.today.iso8601,
            },
          )
        end
        TradeTariffBackend.search_client.indices.refresh(index: 'tariff-test-*')

        allow(AdminConfiguration).to receive(:enabled?).and_call_original
        allow(AdminConfiguration).to receive(:enabled?).with('interactive_search_enabled').and_return(true)
        allow(OpenaiClient).to receive(:call).and_return(ai_response)
      end

      it 'stores meta.usage with cost and token data' do
        worker.perform(search.id)

        usage_meta = search.payload.dig('result', 'meta', 'usage')
        expect(usage_meta).to include('total_tokens' => 160, 'provider_calls' => 1)
        expect(usage_meta).to have_key('total_cost_usd')
        expect(usage_meta).to have_key('duration_ms')
      end
    end

    context 'when an unrelated concurrent search event fires during the job' do
      let(:inputs) { { q: 'trainers', as_of: nil, request_id: 'eval-request-id', answers: [], configuration_overrides: {}, search_type: 'evaluation' } }
      let(:ai_response) do
        AiUsage.attach_metadata(
          '{"answers": [{"commodity_code": "6404110000", "confidence": "strong"}]}',
          AiUsage.metadata_for(model: 'gpt-5.2', event_kind: 'interactive_search', usage: { 'prompt_tokens' => 120, 'completion_tokens' => 40, 'total_tokens' => 160 }),
        )
      end

      before do
        index = Search::GoodsNomenclatureIndex.new
        [
          { sid: 98_001, item_id: '6404110000', description: 'trainers with rubber sole' },
          { sid: 98_002, item_id: '6404190000', description: 'trainers with textile upper' },
        ].each do |doc|
          TradeTariffBackend.search_client.index_by_name(
            index.name,
            doc[:sid],
            {
              goods_nomenclature_sid: doc[:sid],
              goods_nomenclature_item_id: doc[:item_id],
              producline_suffix: '80',
              goods_nomenclature_class: 'Commodity',
              description: doc[:description],
              formatted_description: doc[:description],
              full_description: doc[:description],
              heading_description: 'Footwear',
              declarable: true,
              validity_start_date: Time.zone.today.iso8601,
            },
          )
        end
        TradeTariffBackend.search_client.indices.refresh(index: 'tariff-test-*')

        allow(AdminConfiguration).to receive(:enabled?).and_call_original
        allow(AdminConfiguration).to receive(:enabled?).with('interactive_search_enabled').and_return(true)

        allow(OpenaiClient).to receive(:call) do |*_args, **_kwargs|
          # Simulate a concurrent, unrelated search's LLM call completing on the process-wide
          # ActiveSupport::Notifications Fanout notifier while this job is still subscribed --
          # ActiveSupport::Notifications.subscribed subscribes on that single process-wide
          # notifier for the block's duration, not scoped to this thread/job. A real trader
          # search's QueuedSearchWorker and this worker can run concurrently in the same Sidekiq
          # process. The worker's request_id filter must exclude it from this job's totals.
          ActiveSupport::Notifications.instrument(
            'api_call_completed.search',
            request_id: 'unrelated-concurrent-request-id',
            total_tokens: 999_999,
            total_cost_usd: 999.99,
            duration_ms: 1.0,
            pricing_known: true,
          )

          ai_response
        end
      end

      it "excludes the foreign event from this job's meta.usage" do
        worker.perform(search.id)

        usage_meta = search.payload.dig('result', 'meta', 'usage')
        expect(usage_meta).to include('total_tokens' => 160, 'provider_calls' => 1)
        expect(usage_meta['total_tokens']).not_to eq(160 + 999_999)
        expect(usage_meta['total_cost_usd']).not_to eq(999.99)
      end
    end

    context 'when no LLM call happens (blank query, no results)' do
      let(:inputs) { { q: '', as_of: nil, request_id: 'eval-request-id', answers: [], configuration_overrides: {}, search_type: 'evaluation' } }

      it 'omits meta.usage entirely' do
        worker.perform(search.id)

        expect(search.payload.dig('result', 'meta')).not_to have_key('usage')
      end
    end

    it 'restores request and date context, then does not leak it after execution' do
      attributes = %i[request_id request_source client_id experiment search_failures search_type search_labels_enabled time_machine_now time_machine_relevant]
      previous = attributes.index_with { |attribute| TradeTariffRequest.public_send(attribute) }

      worker.perform(search.id)

      expect(attributes.index_with { |attribute| TradeTariffRequest.public_send(attribute) }).to eq(previous)
    end

    it 'does not execute duplicate deliveries' do
      allow(Api::Internal::SearchService).to receive(:new).and_call_original
      worker.perform(search.id)
      worker.perform(search.id)

      expect(Api::Internal::SearchService).to have_received(:new).once
    end

    it 'skips missing or expired payloads' do
      search.delete
      allow(Api::Internal::SearchService).to receive(:new)

      worker.perform(search.id)

      expect(Api::Internal::SearchService).not_to have_received(:new)
    end

    it 'preserves search validation errors' do
      service = instance_double(Api::Internal::SearchService, request_id: 'eval-request-id')
      allow(Api::Internal::SearchService).to receive(:new).and_return(service)
      allow(service).to receive(:call).and_return({ errors: [{ title: 'Invalid query' }] })

      worker.perform(search.id)

      expect(search.payload).to include('status' => 'failed', 'response_status' => 422, 'result' => { 'errors' => [{ 'title' => 'Invalid query' }] })
    end

    it 'stores safe errors on search failure' do
      service = instance_double(Api::Internal::SearchService, request_id: 'eval-request-id')
      allow(Api::Internal::SearchService).to receive(:new).and_return(service)
      allow(service).to receive(:call).and_raise(StandardError, 'private error')

      expect { worker.perform(search.id) }.to raise_error(StandardError, 'private error')

      expect(search.payload).to include('status' => 'failed', 'response_status' => 500)
      expect(search.payload.to_json).not_to include('private error')
    end
  end
end
