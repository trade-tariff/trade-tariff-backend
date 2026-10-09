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

  describe 'GET #show' do
    let(:search_reference) { create :search_reference, referenced: create(:heading), title: 'original title' }
    let(:json) { JSON.parse(response.body) }

    it 'returns the current search reference with version meta' do
      authenticated_get api_search_reference_path(search_reference.id, format: :json)

      expect(response).to have_http_status(:ok)
      expect(json.dig('data', 'attributes', 'title')).to eq('original title')
      expect(json.dig('meta', 'version')).to include('current' => true, 'latest_event' => 'create')
    end

    it 'returns 404 when the search reference has no record and no history' do
      authenticated_get api_search_reference_path(999_999, format: :json)

      expect(response).to have_http_status(:not_found)
    end

    context 'when viewing a historical version' do
      before { search_reference.update(title: 'updated title') }

      it 'returns the historical state' do
        version = search_reference.versions.order(:id).first

        authenticated_get api_search_reference_path(search_reference.id, filter: { oid: version.id }, format: :json)

        expect(json.dig('data', 'attributes', 'title')).to eq('original title')
        expect(json.dig('meta', 'version')).to include('current' => false, 'oid' => version.id)
      end
    end

    context 'when the search reference has been destroyed' do
      before { search_reference.destroy }

      it 'returns its last known state from the destroy version' do
        version = Version.where(item_type: 'SearchReference', item_id: search_reference.id.to_s, event: 'destroy').first

        authenticated_get api_search_reference_path(search_reference.id, filter: { oid: version.id }, format: :json)

        expect(response).to have_http_status(:ok)
        expect(json.dig('data', 'attributes', 'title')).to eq('original title')
        expect(json.dig('meta', 'version')).to include('current' => false, 'latest_event' => 'destroy')
      end
    end

    context 'when the search reference was removed without a destroy version' do
      before { search_reference.delete }

      it 'returns its last known state' do
        authenticated_get api_search_reference_path(search_reference.id, format: :json)

        expect(response).to have_http_status(:ok)
        expect(json.dig('data', 'attributes', 'title')).to eq('original title')
      end
    end
  end

  describe 'GET #versions' do
    let(:search_reference) { create :search_reference, referenced: create(:heading), title: 'original title' }

    before { search_reference.update(title: 'updated title') }

    it 'returns the versions of the search reference' do
      authenticated_get versions_api_search_reference_path(search_reference.id, format: :json)

      events = JSON.parse(response.body)['data'].map { |version| version.dig('attributes', 'event') }
      expect(events).to eq(%w[create update])
    end

    it 'returns 404 when the search reference has no record and no history' do
      authenticated_get versions_api_search_reference_path(999_999, format: :json)

      expect(response).to have_http_status(:not_found)
    end
  end
end
