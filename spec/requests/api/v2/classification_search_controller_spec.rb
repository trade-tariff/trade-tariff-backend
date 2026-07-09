RSpec.describe 'Classification search API' do
  describe 'GET /classification_search' do
    subject(:make_request) do
      get '/uk/api/classification_search', params: params, headers: request_headers(version: 2)
    end

    let(:params) { { q: 'wireless noise cancelling headphones', limit: 5, request_id: 'test-request-id' } }
    let(:result) do
      GoodsNomenclatureResult.new(
        id: '123',
        goods_nomenclature_item_id: '8518300090',
        goods_nomenclature_sid: 123,
        producline_suffix: '80',
        goods_nomenclature_class: 'Commodity',
        description: 'Headphones and earphones',
        formatted_description: 'Headphones and earphones',
        self_text: 'Headphones and earphones',
        classification_description: 'Headphones and earphones',
        full_description: 'Electrical machinery > Headphones and earphones',
        heading_description: 'Headphones and earphones',
        declarable: true,
        score: 0.03125,
        confidence: nil,
      )
    end

    before do
      allow(AdminConfiguration).to receive(:enabled?).with('input_sanitiser_enabled').and_return(false)
      allow(HybridRetrievalService).to receive(:call).and_return(
        HybridRetrievalService::Result.new(results: [result], expanded_query: 'wireless headphones', source_results: [result]),
      )
    end

    it 'returns a hybrid shortlist' do
      make_request

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include(
        'data' => [
          include(
            'type' => 'classification_search_result',
            'id' => '123',
            'attributes' => include(
              'goods_nomenclature_item_id' => '8518300090',
              'goods_nomenclature_sid' => 123,
              'declarable' => true,
              'score' => 0.03125,
            ),
          ),
        ],
        'meta' => include(
          'request_id' => 'test-request-id',
          'retrieval_method' => 'hybrid',
          'expanded_query' => 'wireless headphones',
          'result_count' => 1,
          'max_score' => 0.03125,
        ),
      )
    end

    it 'passes bounded retrieval arguments' do
      make_request

      expect(HybridRetrievalService).to have_received(:call).with(
        query: 'wireless noise cancelling headphones',
        expanded_query: nil,
        as_of: Time.zone.today,
        request_id: 'test-request-id',
        limit: 5,
      )
    end

    context 'without a query' do
      let(:params) { {} }

      it 'returns an empty shortlist' do
        make_request

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          'data' => [],
          'meta' => include('retrieval_method' => 'hybrid', 'result_count' => 0),
        )
      end
    end

    context 'with invalid input' do
      let(:params) { { q: "bad\u0001query" } }

      before do
        allow(AdminConfiguration).to receive(:enabled?).with('input_sanitiser_enabled').and_return(true)
        allow(AdminConfiguration).to receive(:integer_value).with('input_sanitiser_max_length').and_return(1000)
      end

      it 'returns a validation error' do
        make_request

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)).to include('errors' => [include('title' => 'Invalid query')])
      end
    end

    context 'when hybrid retrieval fails' do
      before do
        allow(HybridRetrievalService).to receive(:call).and_raise(HybridRetrievalService::AllLegsFailed, 'all legs failed')
      end

      it 'returns a backend error' do
        make_request

        expect(response).to have_http_status(:internal_server_error)
        expect(JSON.parse(response.body)).to include('errors' => [include('title' => 'Classification search failed')])
      end
    end
  end
end
