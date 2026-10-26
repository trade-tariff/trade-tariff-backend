require 'rails_helper'

RSpec.describe Api::Admin::Search::Evaluation::SyntheticInputSetItemsController, :admin do
  subject(:api_response) do
    make_request
    response
  end

  let(:json_response) { JSON.parse(api_response.body) }
  let(:synthetic_input_set) { create(:evaluation_synthetic_input_set) }

  describe 'GET #index' do
    let(:make_request) { authenticated_get api_admin_search_evaluation_synthetic_input_set_items_path(synthetic_input_set.id, format: :json, **query) }
    let(:query) { {} }

    let!(:items) do
      [
        create(:evaluation_synthetic_input_set_item, evaluation_synthetic_input_set: synthetic_input_set, query: 'first query', expected_code: '3924100000'),
        create(:evaluation_synthetic_input_set_item, evaluation_synthetic_input_set: synthetic_input_set, query: 'second query', expected_code: '4201000000'),
      ]
    end

    before { create(:evaluation_synthetic_input_set_item) }

    it { is_expected.to have_http_status :ok }

    it 'lists only the items of this set, in the order they were added' do
      expect(json_response['data'].pluck('id')).to eq(items.map { |item| item.id.to_s })
      expect(json_response['data'].pluck('type').uniq).to eq(%w[synthetic_input_set_item])
    end

    it 'gives each item the fields an operator needs to read it' do
      expect(json_response['data'].first['attributes']).to include(
        'synthetic_input_set_id' => synthetic_input_set.id,
        'synthetic_atar_id' => items.first.synthetic_atar_id,
        'query' => 'first query',
        'expected_code' => '3924100000',
      )
    end

    it 'reports the pagination of the whole set' do
      expect(json_response.dig('meta', 'pagination')).to eq('page' => 1, 'per_page' => 20, 'total_count' => 2)
    end

    context 'when asking for the second page of one' do
      let(:query) { { page: 2, per_page: 1 } }

      it 'returns the second item and the size of the whole set' do
        expect(json_response['data'].pluck('id')).to eq([items.second.id.to_s])
        expect(json_response.dig('meta', 'pagination')).to eq('page' => 2, 'per_page' => 1, 'total_count' => 2)
      end
    end

    context 'when the set does not exist' do
      let(:make_request) { authenticated_get api_admin_search_evaluation_synthetic_input_set_items_path(0, format: :json) }

      it { is_expected.to have_http_status :not_found }
    end
  end
end
