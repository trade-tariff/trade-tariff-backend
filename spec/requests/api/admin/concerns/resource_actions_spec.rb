RSpec.describe Api::Admin::ResourceActions, :admin, type: :request do
  # Test the concern behaviour through ExemptionsController as a representative example.
  # The full HTTP-level integration for each action is covered in the respective
  # controller request specs (e.g. green_lanes/exemptions_controller_spec.rb).

  let(:exemption) { create(:green_lanes_exemption) }

  before do
    allow(TradeTariffBackend).to receive(:service).and_return('xi')
  end

  describe 'GET #show' do
    it 'returns 200 with the serialized record' do
      authenticated_get api_admin_green_lanes_exemption_path(exemption.id, format: :json)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include('data')
    end

    it 'returns 404 when record does not exist' do
      authenticated_get api_admin_green_lanes_exemption_path(99_999, format: :json)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      { data: { type: :green_lanes_exemption, attributes: build(:green_lanes_exemption).to_hash } }
    end
    let(:invalid_params) do
      { data: { type: :green_lanes_exemption, attributes: build(:green_lanes_exemption, code: nil).to_hash } }
    end

    it 'creates the record and returns 201' do
      expect {
        authenticated_post api_admin_green_lanes_exemptions_path(format: :json), params: valid_params
      }.to change(GreenLanes::Exemption, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it 'returns 422 when params are invalid' do
      authenticated_post api_admin_green_lanes_exemptions_path(format: :json), params: invalid_params
      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)).to include('errors')
    end
  end

  describe 'PATCH #update' do
    it 'updates the record and returns 200' do
      authenticated_patch api_admin_green_lanes_exemption_path(exemption.id, format: :json), params: {
        data: { type: :green_lanes_exemption, attributes: { description: 'updated' } },
      }
      expect(response).to have_http_status(:ok)
    end

    it 'returns 422 when params are invalid' do
      authenticated_patch api_admin_green_lanes_exemption_path(exemption.id, format: :json), params: {
        data: { type: :green_lanes_exemption, attributes: { code: nil } },
      }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 404 when record does not exist' do
      authenticated_patch api_admin_green_lanes_exemption_path(99_999, format: :json), params: {
        data: { type: :green_lanes_exemption, attributes: { description: 'x' } },
      }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the record and returns 204' do
      id = exemption.id
      expect {
        authenticated_delete api_admin_green_lanes_exemption_path(id, format: :json)
      }.to change(GreenLanes::Exemption, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it 'returns 404 when record does not exist' do
      authenticated_delete api_admin_green_lanes_exemption_path(99_999, format: :json)
      expect(response).to have_http_status(:not_found)
    end
  end
end
