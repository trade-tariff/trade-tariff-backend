require 'rails_helper'

RSpec.describe Api::Admin::Search::Evaluation::SearchesController, :admin do
  subject(:api_response) do
    make_request
    response
  end

  let(:json_response) { JSON.parse(api_response.body) }
  let(:make_request) { authenticated_post api_admin_search_evaluation_searches_path(format: :json), params: params, as: :json }

  before do
    # Force the opensearch-only retrieval path (mirrors spec/requests/api/internal/search_controller_spec.rb
    # and spec/services/api/internal/search_service_spec.rb) so a real Api::Internal::SearchService call
    # doesn't fall into hybrid/vector retrieval, which would hit the live embeddings API and fail under WebMock.
    allow(AdminConfiguration).to receive(:option_value).and_call_original
    allow(AdminConfiguration).to receive(:option_value).with('retrieval_method').and_return('opensearch')
    allow(AdminConfiguration).to receive(:enabled?).and_call_original
    allow(AdminConfiguration).to receive(:enabled?).with('expand_search_when_needed_enabled').and_return(false)
    allow(ExpandSearchQueryService).to receive(:call).and_wrap_original do |_method, query|
      ExpandSearchQueryService::Result.new(expanded_query: query, reason: nil)
    end
  end

  describe 'POST #create' do
    context 'with a blank query' do
      let(:params) { { q: '' } }

      it { is_expected.to have_http_status :success }
      it { expect(json_response).to eq('data' => []) }
    end

    context 'with a disallowed configuration_overrides key' do
      let(:params) { { q: 'horses', configuration_overrides: { 'use_kg_context' => true } } }

      it { is_expected.to have_http_status :unprocessable_content }
      it { expect(json_response).to include('errors') }
    end

    context 'with an allowed key but an invalid value' do
      let(:params) { { q: 'horses', configuration_overrides: { 'rrf_k' => 'abc' } } }

      it { is_expected.to have_http_status :unprocessable_content }
      it { expect(json_response).to include('errors') }
    end

    context 'with an allowed configuration_overrides key' do
      let(:params) { { q: 'horses', configuration_overrides: { 'candidate_limit' => 5 } } }

      before do
        allow(Api::Internal::SearchService).to receive(:new).and_call_original
      end

      it { is_expected.to have_http_status :success }

      it 'passes configuration_overrides through to Api::Internal::SearchService' do
        api_response
        expect(Api::Internal::SearchService).to have_received(:new).with(
          hash_including(configuration_overrides: hash_including('candidate_limit' => 5)),
        )
      end

      it "still tags the call with search_type: 'evaluation'" do
        api_response
        expect(Api::Internal::SearchService).to have_received(:new).with(
          hash_including(search_type: 'evaluation'),
        )
      end
    end

    context 'without any configuration_overrides' do
      let(:params) { { q: 'horses' } }

      before do
        allow(Api::Internal::SearchService).to receive(:new).and_call_original
      end

      it 'still calls Api::Internal::SearchService, with an empty configuration_overrides' do
        api_response
        expect(Api::Internal::SearchService).to have_received(:new).with(
          hash_including(configuration_overrides: {}),
        )
      end
    end

    context 'with or without configuration_overrides' do
      let(:params) { { q: 'horses' } }

      before do
        allow(Api::Internal::SearchService).to receive(:new).and_call_original
      end

      it "tags the call with search_type: 'evaluation', regardless of configuration_overrides" do
        api_response
        expect(Api::Internal::SearchService).to have_received(:new).with(
          hash_including(search_type: 'evaluation'),
        )
      end
    end

    context 'when a real interactive search LLM call happens' do
      let(:params) { { q: 'trainers' } }
      let(:usage) { { 'prompt_tokens' => 120, 'completion_tokens' => 40, 'total_tokens' => 160 } }
      let(:ai_response) do
        AiUsage.attach_metadata(
          '{"answers": [{"commodity_code": "6404110000", "confidence": "strong"}]}',
          AiUsage.metadata_for(model: 'gpt-5.2', event_kind: 'interactive_search', usage:),
        )
      end

      before do
        # Index TWO real documents so opensearch_results.size > 1 and
        # InteractiveSearchService doesn't take the single_result? short
        # circuit (which makes no LLM call at all, and so would make this
        # test pass for the wrong reason). Same real-indexing pattern
        # spec/requests/api/internal/search_controller_spec.rb already uses
        # (see its 'when query expansion times out' context) — copy that
        # pattern exactly rather than hand-building GoodsNomenclatureResult
        # objects, since the serializer touches more fields than are
        # convenient to fake by hand.
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

      it 'includes meta.usage with cost and token data' do
        api_response
        usage_meta = json_response.dig('meta', 'usage')
        expect(usage_meta).to include('total_tokens' => 160)
        expect(usage_meta).to have_key('total_cost_usd')
        expect(usage_meta).to have_key('duration_ms')
      end
    end

    context 'when the duplicate-question-retry path fires more than one LLM call' do
      let(:params) do
        {
          q: 'hiking boots',
          answers: [
            { question: 'Is this item made of leather or synthetic material?', answer: 'Leather', options: %w[Leather Synthetic] },
          ],
        }
      end

      # Three distinct AiUsage-tagged responses, one per real LLM call this path makes
      # (see interactive_search_service.rb:437-443 and duplicate_question_guard.rb:115-136):
      #   1. the initial interactive_search call, which repeats a question the user
      #      already answered (so DuplicateQuestionGuard's repeated_question_text?
      #      signal fires)
      #   2. DuplicateQuestionGuard's own duplicate_question_validator call, confirming
      #      it's a duplicate
      #   3. InteractiveSearchService's duplicate_question_retry call, giving a final
      #      answer
      # Each carries a different total_tokens value so the test can prove the
      # controller sums across all events instead of only reading the first one.
      let(:call_responses) do
        [
          AiUsage.attach_metadata(
            '{"questions": [{"question": "Is this item made of leather or synthetic material?", "options": ["Leather", "Synthetic"]}]}',
            AiUsage.metadata_for(model: 'gpt-5.2', event_kind: 'interactive_search', usage: { 'total_tokens' => 100 }),
          ),
          AiUsage.attach_metadata(
            '{"duplicate": true, "reason": "Repeats the already answered material distinction"}',
            AiUsage.metadata_for(model: 'gpt-5.2', event_kind: 'duplicate_question_validator', usage: { 'total_tokens' => 50 }),
          ),
          AiUsage.attach_metadata(
            '{"answers": [{"commodity_code": "6403910000", "confidence": "strong"}]}',
            AiUsage.metadata_for(model: 'gpt-5.2', event_kind: 'duplicate_question_retry', usage: { 'total_tokens' => 60 }),
          ),
        ]
      end

      before do
        index = Search::GoodsNomenclatureIndex.new
        [
          { sid: 98_101, item_id: '6403910000', description: 'hiking boots with rubber sole' },
          { sid: 98_102, item_id: '6403990000', description: 'hiking boots with leather upper' },
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
        allow(AdminConfiguration).to receive(:enabled?).with('interactive_search_duplicate_question_guard_enabled').and_return(true)

        # Responses are matched by call order, not prompt content, because the
        # duplicate-question-guard's validator prompt template
        # (interactive_search_duplicate_question_guard_context) isn't seeded in the
        # test database and would otherwise render as an empty string, making
        # content-based matching unreliable.
        responses = call_responses.dup
        allow(OpenaiClient).to receive(:call) { responses.shift }
      end

      it 'sums usage across all LLM calls rather than only the first' do
        api_response
        usage_meta = json_response.dig('meta', 'usage')
        expect(OpenaiClient).to have_received(:call).exactly(3).times
        expect(usage_meta).to include('total_tokens' => 210)
      end
    end

    context 'when no LLM call happens (blank query, no results)' do
      let(:params) { { q: '' } }

      it 'omits meta.usage entirely' do
        api_response
        # `not_include` isn't a real RSpec matcher (no such built-in exists); dig handles
        # both "meta is absent" and "meta present but without usage" in one assertion.
        expect(json_response.dig('meta', 'usage')).to be_nil
      end
    end
  end
end
