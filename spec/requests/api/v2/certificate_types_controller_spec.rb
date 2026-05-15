RSpec.describe Api::V2::CertificateTypesController, type: :request do
  describe 'GET #index' do
    subject(:api_response) do
      make_request
      response
    end

    let(:make_request) do
      get '/uk/api/certificate_types.json', headers: request_headers(format: :json)
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

    it { expect(api_response.body).to match_json_expression(pattern) }
  end
end
