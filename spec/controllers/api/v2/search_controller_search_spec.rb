RSpec.describe Api::V2::SearchController do
  describe 'GET /search' do
    subject(:response) { get :search, params: { q: chapter.to_param, as_of: chapter.validity_start_date } }

    let(:chapter) { create :chapter }

    it { expect(response).to have_http_status(:ok) }
  end

  describe 'POST /search' do
    context 'when an exact match' do
      before do
        post :search, params: { q: chapter.to_param, as_of: chapter.validity_start_date }
      end

      let(:chapter) { create :chapter }
      let(:pattern) do
        {
          data: {
            id: String,
            type: 'exact_search',
            attributes: {
              type: 'exact_match',
              entry: {
                endpoint: 'chapters',
                id: chapter.to_param,
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

  describe 'GET /suggestions' do
    subject(:response) { get :suggestions }

    before do
      create(:heading, :with_search_reference, title: 'same')
      create(:commodity, :with_search_reference, title: 'same')
      create(:chapter, :with_search_reference, title: 'but different')
    end

    it { expect(response.body.scan(/same/).size).to eq(1) }
    it { expect(response.body.scan(/but different/).size).to eq(1) }

    it_behaves_like 'a successful jsonapi response'
  end
end
