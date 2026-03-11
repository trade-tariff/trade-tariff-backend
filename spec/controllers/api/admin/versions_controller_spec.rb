RSpec.describe Api::Admin::VersionsController do
  routes { AdminApi.routes }

  describe '#index' do
    let(:commodity) { create :commodity }

    before do
      label = create :goods_nomenclature_label, goods_nomenclature: commodity
      label.update(description: 'changed label')

      self_text = create :goods_nomenclature_self_text, goods_nomenclature: commodity
      self_text.update(self_text: 'changed text')
    end

    it 'returns all versions ordered by most recent first' do
      get :index, format: :json

      json = JSON.parse(response.body)
      expect(json['data'].length).to be >= 4
      expect(json['data'].first['type']).to eq('version')

      timestamps = json['data'].map { |v| v.dig('attributes', 'created_at') }
      expect(timestamps).to eq(timestamps.sort.reverse)
    end

    it 'includes pagination meta' do
      get :index, format: :json

      json = JSON.parse(response.body)
      expect(json['meta']['pagination']).to include(
        'page' => 1,
        'per_page' => Integer,
        'total_count' => Integer,
      )
    end

    it 'filters by item_type' do
      get :index, params: { item_type: 'GoodsNomenclatureLabel' }, format: :json

      json = JSON.parse(response.body)
      types = json['data'].map { |v| v.dig('attributes', 'item_type') }.uniq
      expect(types).to eq(%w[GoodsNomenclatureLabel])
    end

    it 'paginates results' do
      get :index, params: { page: 1, per_page: 2 }, format: :json

      json = JSON.parse(response.body)
      expect(json['data'].length).to be <= 2
      expect(json['meta']['pagination']['per_page']).to eq(2)
    end
  end

  describe '#restore' do
    context 'with an AdminConfiguration' do
      let!(:config) { create(:admin_configuration, name: 'restore_test', value: 'original') }

      before { config.update(value: 'changed') }

      it 'restores the record to a previous version' do
        version = config.versions.first

        post :restore, params: { id: version.id }, format: :json

        expect(response).to have_http_status(:ok)
        expect(config.reload[:value]).to eq('original')
      end

      it 'creates a new version recording the restore' do
        version = config.versions.first

        expect {
          post :restore, params: { id: version.id }, format: :json
        }.to change { Version.where(item_type: 'AdminConfiguration', item_id: 'restore_test').count }.by(1)
      end

      it 'returns the new version' do
        version = config.versions.first

        post :restore, params: { id: version.id }, format: :json

        json = JSON.parse(response.body)
        expect(json['data']['type']).to eq('version')
        expect(json['data']['attributes']['event']).to eq('update')
      end
    end

    context 'with a GoodsNomenclatureLabel' do
      let(:commodity) { create :commodity }
      let!(:label) do
        create :goods_nomenclature_label,
               goods_nomenclature: commodity,
               description: 'original'
      end

      before { label.update(description: 'changed') }

      it 'restores the label to a previous version' do
        version = label.versions.first

        post :restore, params: { id: version.id }, format: :json

        expect(response).to have_http_status(:ok)
        expect(label.reload.description).to eq('original')
      end
    end

    context 'with a GoodsNomenclatureSelfText' do
      let!(:self_text) { create :goods_nomenclature_self_text, self_text: 'original text' }

      before { self_text.update(self_text: 'changed text') }

      it 'restores the self text to a previous version' do
        version = self_text.versions.first

        post :restore, params: { id: version.id }, format: :json

        expect(response).to have_http_status(:ok)
        expect(self_text.reload.self_text).to eq('original text')
      end
    end

    context 'when version does not exist' do
      it 'returns 404' do
        post :restore, params: { id: 999_999 }, format: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when the original record has been deleted' do
      it 're-creates the record and returns 200' do
        config = create(:admin_configuration, name: 'deleted_test', value: 'original')
        version = config.versions.first
        config.destroy

        expect {
          post :restore, params: { id: version.id }, format: :json
        }.to change { AdminConfiguration.where(name: 'deleted_test').count }.from(0).to(1)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when restoring a model whose primary key is not id' do
      let!(:config) { create(:admin_configuration, name: 'pk_test', value: 'before') }

      before { config.update(value: 'after') }

      it 'excludes the id column from mass assignment' do
        version = config.versions.first

        expect {
          post :restore, params: { id: version.id }, format: :json
        }.not_to raise_error

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
