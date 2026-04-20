RSpec.describe Api::V2::SearchReferencesController do
  before do
    TradeTariffRequest.time_machine_now = Time.current
    create :search_reference, referenced: create(:heading), title: 'aa'
    create :search_reference, referenced: create(:chapter), title: 'bb'
  end

  describe 'GET #index' do
    context 'when a valid query[letter] param is provided' do
      it 'returns a successful response' do
        api_get '/uk/api/search_references', params: { query: { letter: 'a' } }

        expect(response).to be_successful
      end

      it 'filters results by letter' do
        api_get '/uk/api/search_references', params: { query: { letter: 'a' } }

        data = JSON.parse(response.body)['data']
        expect(data.count).to eq(1)
      end
    end

    context 'when no query param is provided' do
      it 'returns a successful response' do
        api_get '/uk/api/search_references'

        expect(response).to be_successful
      end
    end

    context 'when query is a scalar rather than a hash (e.g. ?query=foo)' do
      it 'returns a successful response without raising' do
        api_get '/uk/api/search_references', params: { query: 'foo' }

        expect(response).to be_successful
      end
    end
  end
end
