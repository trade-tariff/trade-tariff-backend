RSpec.describe Api::V2::SearchController do
  describe 'GET /search' do
    subject(:api_response) do
      make_request
      response
    end

    let(:make_request) do
      get '/uk/api/search', params: { q: chapter.to_param, as_of: chapter.validity_start_date }, headers: request_headers
    end

    let(:chapter) { create :chapter }

    it { is_expected.to have_http_status(:ok) }
  end

  describe 'POST /search' do
    context 'when an exact match' do
      before do
        goods_nomenclature = create :chapter, goods_nomenclature_item_id: '0100000000'

        create(:search_suggestion, :goods_nomenclature, goods_nomenclature:)

        post '/uk/api/search', params: { q: '01', as_of: Time.zone.today.iso8601 }, headers: request_headers, as: :json
      end

      let(:pattern) do
        {
          data: {
            id: String,
            type: 'exact_search',
            attributes: {
              type: 'exact_match',
              entry: {
                endpoint: 'chapters',
                id: '01',
              },
            },
          },
        }
      end

      it { expect(response).to have_http_status(:ok) }
      it { expect(response.body).to match_json_expression(pattern) }
    end

    context 'when fuzzy matching' do
      before do
        post '/uk/api/search', params: { q: chapter.description, as_of: chapter.validity_start_date }, headers: request_headers, as: :json
      end

      let(:chapter) { create :chapter, :with_description, description: 'horse', validity_start_date: Time.zone.today }

      let(:pattern) do
        {
          data: {
            id: String,
            type: 'fuzzy_search',
            attributes: {
              type: 'fuzzy_match',
              reference_match: {
                commodities: Array,
                headings: Array,
                chapters: Array,
              },
              goods_nomenclature_match: {
                commodities: Array,
                headings: Array,
                chapters: Array,
              },
            },
          },
        }
      end

      it { expect(response).to have_http_status(:ok) }
      it { expect(response.body).to match_json_expression(pattern) }
    end

    context 'when no matches are found' do
      before { post '/uk/api/search', headers: request_headers, as: :json }

      let(:pattern) do
        {
          data: {
            id: String,
            type: 'null_search',
            attributes: {
              type: 'null_match',
              reference_match: {
                commodities: [],
                headings: [],
                chapters: [],
              },
              goods_nomenclature_match: {
                commodities: [],
                headings: [],
                chapters: [],
              },
            },
          },
        }
      end

      it { expect(response).to have_http_status(:ok) }
      it { expect(response.body).to match_json_expression(pattern) }
    end
  end

  describe 'GET /search_suggestions' do
    context 'when a query is provided' do
      subject(:api_response) do
        make_request
        response
      end

      let(:make_request) do
        get '/uk/api/search_suggestions', params: { q: 'same' }, headers: request_headers
      end

      let(:pattern) do
        {
          'data' => [
            {
              'id' => be_present,
              'type' => 'search_suggestion',
              'attributes' => {
                'value' => 'same',
                'score' => 1.0,
                'query' => 'same',
                'suggestion_type' => 'search_reference',
                'priority' => 1,
                'goods_nomenclature_class' => 'Heading',
              },
            },
          ],
        }
      end

      before do
        create(:search_suggestion, :search_reference, value: 'same')
        create(:search_suggestion, :search_reference, value: 'but different')
      end

      it { expect(api_response.body).to match_json_expression pattern }

      it_behaves_like 'a successful jsonapi response'
    end

    context 'when no query is provided' do
      subject(:api_response) do
        make_request
        response
      end

      let(:make_request) do
        get '/uk/api/search_suggestions', headers: request_headers
      end

      it_behaves_like 'a successful jsonapi response'
    end
  end
end
