RSpec.describe Api::Admin::SearchReferencesController, :admin do
  before do
    TradeTariffRequest.time_machine_now = Time.current
    create :search_reference, referenced: create(:heading), title: 'aa'
    create :search_reference, referenced: create(:chapter), title: 'bb'
    create :search_reference, referenced: create(:commodity), title: 'bb'
  end

  describe 'GET #index' do
    subject(:api_response) do
      make_request
      response
    end

    let(:make_request) do
      authenticated_get api_search_references_path(params: query_letter, format: :json)
    end

    context 'when letter is provided' do
      let(:query_letter) { { query: { letter: 'A' } } }

      it 'performs lookup with provided letter' do
        api_response

        search_ref_count = JSON.parse(response.body)['data'].count
        expect(search_ref_count).to eq(1)
      end
    end

    context 'with no letter param' do
      let(:query_letter) { {} }

      it 'does not filter by letter' do
        api_response

        search_ref_count = JSON.parse(response.body)['data'].count
        expect(search_ref_count).to eq(3)
      end
    end

    context 'with a usage filter' do
      let(:query_letter) { { filter: { usage: 'fpo' } } }

      before { create :search_reference, referenced: create(:heading), title: 'cc', usage: 'fpo' }

      it 'returns only references with the requested usage' do
        api_response

        titles = JSON.parse(response.body)['data'].map { |ref| ref.dig('attributes', 'title') }
        expect(titles).to eq(%w[cc])
      end
    end

    context 'without a usage filter' do
      let(:query_letter) { {} }

      before { create :search_reference, referenced: create(:heading), title: 'cc', usage: 'fpo' }

      it 'excludes fpo references' do
        api_response

        titles = JSON.parse(response.body)['data'].map { |ref| ref.dig('attributes', 'title') }
        expect(titles).not_to include('cc')
      end
    end
  end
end
