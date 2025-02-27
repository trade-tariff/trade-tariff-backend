RSpec.describe Api::Admin::SearchReferencesController, type: :request do
  before do
    TradeTariffRequest.time_machine_now = Time.current
    create :search_reference, referenced: create(:heading), title: 'aa'
    create :search_reference, referenced: create(:chapter), title: 'bb'
    create :search_reference, referenced: create(:commodity), title: 'bb'
  end

  describe 'GET #index' do
    subject(:do_request) do
      authenticated_get api_search_references_path(params: query_letter, format: :json)
      response
    end

    context 'when letter is provided' do
      let(:query_letter) { { query: { letter: 'A' } } }

      it { is_expected.to be_successful }

      it 'performs lookup with provided letter' do
        do_request

        search_ref_count = JSON.parse(response.body)['data'].count
        expect(search_ref_count).to eq(1)
      end
    end

    context 'with no letter param' do
      let(:query_letter) { {} }

      it { is_expected.to be_successful }

      it 'does not filter by letter' do
        do_request

        search_ref_count = JSON.parse(response.body)['data'].count
        expect(search_ref_count).to eq(3)
      end
    end
  end
end
