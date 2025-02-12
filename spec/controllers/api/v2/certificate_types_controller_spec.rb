RSpec.describe Api::V2::CertificateTypesController, type: :controller do
  routes { V2Api.routes }

  describe 'GET #index' do
    subject(:do_response) do
      get :index, format: :json

      response.body
    end

    let(:certificate_type) { create(:certificate_type, :with_description) }

    let(:pattern) do
      {
        "data": [
          {
            "id": String,
            "type": 'certificate_type',
            "attributes": {
              "certificate_type_code": String,
              "description": String,
            },
          },
        ],
      }
    end

    before do
      certificate_type
    end

    it { is_expected.to match_json_expression(pattern) }
  end
end
