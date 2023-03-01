RSpec.describe Api::V2::SearchController do
  describe 'GET /search_suggestions' do
    subject(:response) do
      get :suggestions, params: { q: search_suggestion.value }
    end

    let(:params) { {} }

    let(:search_suggestion) { create :search_suggestion, value: 'testing' }

    let(:pattern) do
      {
        'data' => [
          {
            'id' => 'test',
            'type' => 'search_suggestion',
            'attributes' => {
              'value' => 'testing',
              'score' => 1.0,
              'query' => 'testing',
            },
          },
        ],
      }
    end

    it { expect(response.body).to match_json_expression pattern }
  end
end
