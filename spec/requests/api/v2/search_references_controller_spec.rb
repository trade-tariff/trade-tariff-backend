RSpec.describe Api::V2::SearchReferencesController do
  before do
    TradeTariffRequest.time_machine_now = Time.current
    create :search_reference, referenced: create(:heading), title: 'aa'
    create :search_reference, referenced: create(:chapter), title: 'bb'
  end

  describe 'GET #index' do
    context 'when a valid query[letter] param is provided' do
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

    context 'when fpo references exist' do
      before { create :search_reference, referenced: create(:heading), title: 'ab fpo', usage: 'fpo' }

      def titles
        JSON.parse(response.body)['data'].map { |ref| ref.dig('attributes', 'title') }
      end

      it 'excludes fpo references by default' do
        api_get '/uk/api/search_references'

        expect(titles).to contain_exactly('aa', 'bb')
      end

      it 'returns only fpo references with filter[usage]=fpo' do
        api_get '/uk/api/search_references', params: { filter: { usage: 'fpo' } }

        expect(titles).to eq(['ab fpo'])
      end

      it 'returns every reference with filter[usage]=all' do
        api_get '/uk/api/search_references', params: { filter: { usage: 'all' } }

        expect(titles).to contain_exactly('aa', 'ab fpo', 'bb')
      end

      it 'combines the usage filter with the letter filter' do
        api_get '/uk/api/search_references', params: { filter: { usage: 'all' }, query: { letter: 'a' } }

        expect(titles).to contain_exactly('aa', 'ab fpo')
      end

      it 'includes the usage attribute' do
        api_get '/uk/api/search_references', params: { filter: { usage: 'fpo' } }

        expect(JSON.parse(response.body)['data'].first.dig('attributes', 'usage')).to eq('fpo')
      end

      it 'returns bad request for an unknown usage' do
        api_get '/uk/api/search_references', params: { filter: { usage: 'other' } }

        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
