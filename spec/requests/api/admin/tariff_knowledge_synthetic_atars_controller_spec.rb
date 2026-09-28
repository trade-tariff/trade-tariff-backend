RSpec.describe Api::Admin::TariffKnowledgeSyntheticAtarsController do
  let(:headers) { request_headers(format: :json) }

  describe '#index' do
    before do
      create(:tariff_knowledge_synthetic_atar, real_user_search: 'saddle', chapter: '42', goods_nomenclature_item_id: '4201000000', description: 'Leather riding saddle for a pony.')
      create(:tariff_knowledge_synthetic_atar, real_user_search: 'plastic box', chapter: '39')
      create(:tariff_knowledge_synthetic_atar, real_user_search: 'bucket', chapter: '39', description: 'Plastic bucket with a metal handle.')
    end

    it 'returns all records ordered by chapter and then search' do
      get '/uk/admin/tariff_knowledge_synthetic_atars.json', headers: headers

      json = JSON.parse(response.body)
      expect(json['data'].map { |row| row['type'] }.uniq).to eq(%w[tariff_knowledge_synthetic_atar])
      expect(json['data'].map { |row| row.dig('attributes', 'real_user_search') }).to eq(['bucket', 'plastic box', 'saddle'])
    end

    it 'includes pagination meta' do
      get '/uk/admin/tariff_knowledge_synthetic_atars.json', headers: headers

      json = JSON.parse(response.body)
      expect(json.dig('meta', 'pagination')).to include('page' => 1, 'per_page' => Integer, 'total_count' => 3)
    end

    it 'filters by search text in the real user search or the description' do
      get '/uk/admin/tariff_knowledge_synthetic_atars.json', params: { q: 'plastic' }, headers: headers

      json = JSON.parse(response.body)
      expect(json['data'].map { |row| row.dig('attributes', 'real_user_search') }).to eq(['bucket', 'plastic box'])
    end

    it 'filters by chapter' do
      get '/uk/admin/tariff_knowledge_synthetic_atars.json', params: { chapter: '42' }, headers: headers

      json = JSON.parse(response.body)
      expect(json['data'].map { |row| row.dig('attributes', 'real_user_search') }).to eq(%w[saddle])
    end
  end

  describe '#show' do
    let!(:synthetic_atar) { create(:tariff_knowledge_synthetic_atar, real_user_search: 'plastic box') }

    it 'returns the record with version metadata' do
      get "/uk/admin/tariff_knowledge_synthetic_atars/#{synthetic_atar.id}.json", headers: headers

      json = JSON.parse(response.body)
      expect(json.dig('data', 'id')).to eq(synthetic_atar.id.to_s)
      expect(json.dig('data', 'attributes')).to include(
        'real_user_search' => 'plastic box',
        'chapter' => '39',
        'goods_nomenclature_item_id' => '3924100000',
        'completed_by' => 'AB',
      )
      expect(json.dig('meta', 'version', 'current')).to be true
    end

    it 'returns 404 when not found' do
      get '/uk/admin/tariff_knowledge_synthetic_atars/999999.json', headers: headers

      expect(response).to have_http_status(:not_found)
    end

    context 'when viewing a historical version' do
      before { synthetic_atar.update(notes: 'Changed note') }

      it 'returns the data as it was in that version' do
        version = synthetic_atar.versions.order(:id).first

        get "/uk/admin/tariff_knowledge_synthetic_atars/#{synthetic_atar.id}.json", params: { filter: { oid: version.id } }, headers: headers

        json = JSON.parse(response.body)
        expect(json.dig('data', 'attributes', 'notes')).to eq('Household tableware and kitchenware of plastics.')
        expect(json.dig('meta', 'version', 'current')).to be false
      end
    end
  end

  describe '#create' do
    let(:attributes) do
      {
        chapter: '39',
        real_user_search: 'lunch box',
        times_searched: 40,
        likely_heading: '3924',
        description: 'Plastic lunch box with a lid, for carrying food.',
        goods_nomenclature_item_id: '3924100000',
        notes: 'Tableware of plastics.',
        completed_by: 'CD',
      }
    end

    it 'creates a record and records who created it' do
      expect {
        post '/uk/admin/tariff_knowledge_synthetic_atars.json',
             params: { data: { type: 'tariff_knowledge_synthetic_atar', attributes: } },
             headers: headers.merge('X-Whodunnit' => 'user-123'),
             as: :json
      }.to change(TariffKnowledge::SyntheticAtar, :count).by(1)

      expect(response).to have_http_status(:created)

      record = TariffKnowledge::SyntheticAtar.last
      expect(record).to have_attributes(real_user_search: 'lunch box', times_searched: 40, completed_by: 'CD')
      expect(record.versions.map(&:whodunnit)).to eq(%w[user-123])
    end

    it 'returns validation errors for invalid attributes' do
      expect {
        post '/uk/admin/tariff_knowledge_synthetic_atars.json',
             params: { data: { type: 'tariff_knowledge_synthetic_atar', attributes: attributes.merge(goods_nomenclature_item_id: '392410000') } },
             headers: headers,
             as: :json
      }.not_to change(TariffKnowledge::SyntheticAtar, :count)

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['errors'].first.dig('source', 'pointer')).to eq('/data/attributes/goods_nomenclature_item_id')
    end

    it 'returns one uniqueness error when the search already exists in different case' do
      create(:tariff_knowledge_synthetic_atar, real_user_search: 'Lunch Box')

      expect {
        post '/uk/admin/tariff_knowledge_synthetic_atars.json',
             params: { data: { type: 'tariff_knowledge_synthetic_atar', attributes: } },
             headers: headers,
             as: :json
      }.not_to change(TariffKnowledge::SyntheticAtar, :count)

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['errors'].map { |error| error['title'] }).to eq(['is already used by another synthetic ATaR'])
    end
  end

  describe '#update' do
    let!(:synthetic_atar) { create(:tariff_knowledge_synthetic_atar, real_user_search: 'plastic box') }

    it 'updates the record' do
      put "/uk/admin/tariff_knowledge_synthetic_atars/#{synthetic_atar.id}.json",
          params: { data: { type: 'tariff_knowledge_synthetic_atar', attributes: { goods_nomenclature_item_id: '3923100000', notes: '' } } },
          headers: headers,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(synthetic_atar.reload).to have_attributes(goods_nomenclature_item_id: '3923100000', notes: nil)
    end

    it 'returns validation errors' do
      put "/uk/admin/tariff_knowledge_synthetic_atars/#{synthetic_atar.id}.json",
          params: { data: { type: 'tariff_knowledge_synthetic_atar', attributes: { description: '' } } },
          headers: headers,
          as: :json

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['errors'].first.dig('source', 'pointer')).to eq('/data/attributes/description')
    end
  end

  describe '#versions' do
    let!(:synthetic_atar) { create(:tariff_knowledge_synthetic_atar) }

    before { synthetic_atar.update(notes: 'Changed note') }

    it 'returns the versions of the record' do
      get "/uk/admin/tariff_knowledge_synthetic_atars/#{synthetic_atar.id}/versions.json", headers: headers

      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(2)
      expect(json['data'].map { |row| row['type'] }.uniq).to eq(%w[version])
    end
  end

  describe '#destroy' do
    let!(:synthetic_atar) { create(:tariff_knowledge_synthetic_atar) }

    it 'deletes the record' do
      expect {
        delete "/uk/admin/tariff_knowledge_synthetic_atars/#{synthetic_atar.id}.json", headers: headers
      }.to change(TariffKnowledge::SyntheticAtar, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'returns 404 when not found' do
      delete '/uk/admin/tariff_knowledge_synthetic_atars/999999.json', headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
