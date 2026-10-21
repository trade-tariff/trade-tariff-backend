RSpec.describe Api::Internal::EvaluationSyntheticInputSetItemsController do
  let(:collection_path) { '/uk/internal/evaluation_synthetic_input_set_items.json' }

  describe 'GET /evaluation_synthetic_input_set_items' do
    let(:set) { create(:evaluation_synthetic_input_set) }
    let!(:item) do
      create(
        :evaluation_synthetic_input_set_item,
        evaluation_synthetic_input_set: set,
        query: 'Reusable plastic food storage box with a clip-on lid, made of polypropylene, for household use.',
        expected_code: '3924100000',
      )
    end

    it 'returns the rows of the given set, serialized for execute_run to consume like a gold query row' do
      get collection_path, params: { set_id: set.id }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['data'].pluck('id')).to eq([item.id.to_s])

      attrs = response.parsed_body['data'].first.fetch('attributes')
      expect(attrs).to eq(
        'query' => 'Reusable plastic food storage box with a clip-on lid, made of polypropylene, for household use.',
        'oracle_text' => 'Reusable plastic food storage box with a clip-on lid, made of polypropylene, for household use.',
        'expected_code' => '3924100000',
        'source_type' => 'synthetic_atar',
        'source_id' => item.synthetic_atar_id.to_s,
        'persona' => 'raw',
      )
    end

    it 'only returns rows belonging to the given set' do
      other_set = create(:evaluation_synthetic_input_set)
      create(:evaluation_synthetic_input_set_item, evaluation_synthetic_input_set: other_set)

      get collection_path, params: { set_id: set.id }

      expect(response.parsed_body['data'].pluck('id')).to eq([item.id.to_s])
    end

    it 'returns nothing for a set that has no rows' do
      get collection_path, params: { set_id: create(:evaluation_synthetic_input_set).id }

      expect(response.parsed_body['data']).to eq([])
    end

    it 'rejects a set_id that is not a number' do
      get collection_path, params: { set_id: 'abc' }

      expect(response).to have_http_status(:bad_request)
    end

    it 'paginates results across pages the same way /evaluation_gold_queries does' do
      other_set = create(:evaluation_synthetic_input_set, requested_size: 2, actual_size: 2)
      first_item = create(:evaluation_synthetic_input_set_item, evaluation_synthetic_input_set: other_set)
      second_item = create(:evaluation_synthetic_input_set_item, evaluation_synthetic_input_set: other_set)

      get collection_path, params: { set_id: other_set.id, page: 1, per_page: 1 }
      first_page_ids = response.parsed_body['data'].pluck('id')
      expect(response.parsed_body.dig('meta', 'pagination')).to eq('page' => 1, 'per_page' => 1, 'total_count' => 2)

      get collection_path, params: { set_id: other_set.id, page: 2, per_page: 1 }
      second_page_ids = response.parsed_body['data'].pluck('id')

      expect(first_page_ids + second_page_ids).to contain_exactly(first_item.id.to_s, second_item.id.to_s)
    end

    it 'does not mount the endpoint for the XI service path' do
      get '/xi/internal/evaluation_synthetic_input_set_items.json'

      expect(response).to have_http_status(:not_found)
    end
  end
end
