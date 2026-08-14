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
  end
end
