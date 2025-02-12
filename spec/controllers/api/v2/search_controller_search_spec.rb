RSpec.describe Api::V2::SearchController do
  routes { V2Api.routes }

  describe 'GET /search' do
    subject(:response) { get :search, params: { q: chapter.to_param, as_of: chapter.validity_start_date } }

    let(:chapter) { create :chapter }

    it { expect(response).to have_http_status(:ok) }
  end

  describe 'POST /search' do
    context 'when an exact match' do
      before do
        goods_nomenclature = create :chapter, goods_nomenclature_item_id: '0100000000'

        create(:search_suggestion, :goods_nomenclature, goods_nomenclature:)

        post :search, params: { q: '01', as_of: Time.zone.today.iso8601 }
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
        post :search, params: { q: chapter.description, as_of: chapter.validity_start_date }
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
                sections: Array,
              },
              goods_nomenclature_match: {
                commodities: Array,
                headings: Array,
                chapters: Array,
                sections: Array,
              },
            },
          },
        }
      end

      it { expect(response).to have_http_status(:ok) }
      it { expect(response.body).to match_json_expression(pattern) }
    end

    context 'when no matches are found' do
      before { post :search }

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
                sections: [],
              },
              goods_nomenclature_match: {
                commodities: [],
                headings: [],
                chapters: [],
                sections: [],
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
      subject(:response) { get :suggestions, params: { q: 'same' } }

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

      it { expect(response.body).to match_json_expression pattern }

      it_behaves_like 'a successful jsonapi response'
    end

    context 'when no query is provided' do
      subject(:response) { get :suggestions }

      it_behaves_like 'a successful jsonapi response'
    end
  end
end
