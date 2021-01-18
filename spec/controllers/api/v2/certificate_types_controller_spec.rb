require 'rails_helper'

describe Api::V2::CertificateTypesController, type: :controller do
  render_views

  describe '#index' do
    let!(:certificate_type_1) { create :certificate_type }
    let!(:certificate_type_description_1) { create :certificate_type_description, certificate_type_code: certificate_type_1.certificate_type_code }
    let!(:certificate_type_2) { create :certificate_type }
    let!(:certificate_type_description_2) { create :certificate_type_description, certificate_type_code: certificate_type_2.certificate_type_code }
    let!(:certificate_type_3) { create :certificate_type }
    let!(:certificate_type_description_3) { create :certificate_type_description, certificate_type_code: certificate_type_3.certificate_type_code }

    let(:pattern) do
      {
        "data": [{
          "id": String,
          "type": 'certificate_type',
          "attributes": {
            "certificate_type_code": String,
            "description": String,
          },
        },
                 {
                   "id": String,
                   "type": 'certificate_type',
                   "attributes": {
                     "certificate_type_code": String,
                     "description": String,
                   },
                 },
                 {
                   "id": String,
                   "type": 'certificate_type',
                   "attributes": {
                     "certificate_type_code": String,
                     "description": String,
                   },
                 }],
      }
    end

    it 'returns all certificate types' do
      get :index, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end
end
