RSpec.describe Api::Internal::EvaluationGoldQueriesController do
  let(:collection_path) { '/uk/internal/evaluation_gold_queries.json' }

  describe 'GET /evaluation_gold_queries' do
    let!(:generic) do
      create(
        :evaluation_gold_query,
        source_type: 'atar', source_id: '600000001', persona: 'emu_generic',
        query: 'bed linen', expected_code: '6302100000', expected_description: 'Bed linen, of cotton',
        notes: 'ported emulator', generator: 'gpt-5-mini'
      )
    end
    let!(:ordinary) do
      create(
        :evaluation_gold_query,
        source_type: 'atar', source_id: '600000001', persona: 'emu_ordinary',
        query: 'cotton bed sheets', expected_code: '6302100000'
      )
    end

    before do
      create(:evaluation_gold_query, source_type: 'atar', source_id: '600000002', persona: 'emu_generic', active: false)
    end

    it 'returns active rows with pagination metadata, excluding inactive rows by default' do
      get collection_path, params: { page: 1, per_page: 10 }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data'].pluck('id')).to contain_exactly(generic.id.to_s, ordinary.id.to_s)
      expect(response.parsed_body.dig('meta', 'pagination', 'total_count')).to eq(2)

      attrs = response.parsed_body['data'].find { |row| row['id'] == generic.id.to_s }.fetch('attributes')
      expect(attrs).to eq(
        'source_type' => 'atar',
        'source_id' => '600000001',
        'persona' => 'emu_generic',
        'query' => 'bed linen',
        'expected_code' => '6302100000',
        'expected_description' => 'Bed linen, of cotton',
        'notes' => 'ported emulator',
        'generator' => 'gpt-5-mini',
        'active' => true,
        'created_at' => generic.created_at.iso8601(3),
      )
    end

    it 'filters by persona' do
      get collection_path, params: { persona: 'emu_ordinary' }

      expect(response.parsed_body['data'].pluck('id')).to eq([ordinary.id.to_s])
    end

    it 'filters by source_type' do
      get collection_path, params: { source_type: 'made_up_type' }

      expect(response.parsed_body['data']).to eq([])
    end

    it 'filters by a bulk comma-separated source_ids list' do
      other = create(:evaluation_gold_query, source_type: 'atar', source_id: '600000009', persona: 'emu_generic')

      get collection_path, params: { source_ids: "#{generic.source_id}, #{other.source_id}" }

      expect(response.parsed_body['data'].pluck('id')).to contain_exactly(generic.id.to_s, ordinary.id.to_s, other.id.to_s)
    end

    it 'rejects a supplied source_ids filter without values' do
      get collection_path, params: { source_ids: ', ,' }

      expect(response).to have_http_status(:bad_request)
    end

    it 'does not mount the endpoint for the XI service path' do
      get '/xi/internal/evaluation_gold_queries.json'

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /evaluation_gold_queries/:id' do
    it 'returns one gold query by id' do
      record = create(:evaluation_gold_query)

      get "/uk/internal/evaluation_gold_queries/#{record.id}.json"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('data', 'id')).to eq(record.id.to_s)
    end

    it 'returns not found for an unknown id' do
      get '/uk/internal/evaluation_gold_queries/999999999.json'

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found for an inactive row, matching index excluding it too' do
      record = create(:evaluation_gold_query, active: false)

      get "/uk/internal/evaluation_gold_queries/#{record.id}.json"

      expect(response).to have_http_status(:not_found)
    end

    it 'returns not found for a non-integer id instead of a 500' do
      get '/uk/internal/evaluation_gold_queries/abc.json'

      expect(response).to have_http_status(:not_found)
    end
  end
end
