RSpec.describe Api::Admin::AdminConfigurationsController, :admin do
  let(:json_response) { JSON.parse(response.body) }

  describe 'GET #index' do
    it 'returns a list of configurations' do
      create(:admin_configuration, name: 'test_config')

      authenticated_get api_admin_admin_configurations_path(format: :json)

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('data')
      expect(json_response['data'].size).to eq(1)
      expect(json_response['data'].first['attributes']['name']).to eq('test_config')
    end
  end

  describe 'GET #show' do
    it 'returns a single configuration with version meta' do
      config = create(:admin_configuration, name: 'show_config')

      authenticated_get api_admin_admin_configuration_path(config.name, format: :json)

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('data')
      expect(json_response['data']['id']).to eq('show_config')
      expect(json_response['data']['attributes']['name']).to eq('show_config')
      expect(json_response['data']['attributes']['config_type']).to eq('string')
      expect(json_response['meta']['version']).to include('current', 'oid', 'previous_oid', 'has_previous_version')
      expect(json_response['meta']['version']['current']).to be true
    end

    it 'returns a historical version with filter[oid]' do
      config = create(:admin_configuration, name: 'history_config', value: 'original')

      # Create a second version
      config.set(value: 'updated', operation_date: Time.zone.today)
      config.save_with_refresh

      latest_oid = AdminConfiguration::Operation
        .where(name: 'history_config')
        .order(Sequel.desc(:oid))
        .get(:oid)

      authenticated_get api_admin_admin_configuration_path('history_config', format: :json),
                        params: { filter: { oid: latest_oid } }

      expect(response).to have_http_status(:ok)
      expect(json_response['data']['attributes']['value']).to eq('original')
      expect(json_response['meta']['version']['current']).to be false
    end

    it 'returns 404 if the configuration does not exist' do
      authenticated_get api_admin_admin_configuration_path('nonexistent', format: :json)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH #update' do
    before { create(:admin_configuration, name: 'update_config', value: 'original') }

    let(:update_data) do
      {
        value: 'updated value',
        description: 'Updated description',
      }
    end

    context 'when valid' do
      it 'updates the configuration' do
        authenticated_patch api_admin_admin_configuration_path('update_config', format: :json),
                            params: { data: { type: 'admin_configurations', attributes: update_data } }

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['attributes']['value']).to eq('updated value')
        expect(json_response['data']['attributes']['description']).to eq('Updated description')
        expect(json_response['meta']['version']).to be_present
      end
    end
  end
end
