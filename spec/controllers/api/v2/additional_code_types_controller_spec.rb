RSpec.describe Api::V2::AdditionalCodeTypesController, type: :controller do
  routes { V2Api.routes }

  describe '#index' do
    let(:pattern) do
      {
        "data": [
          {
            "id": String,
            "type": 'additional_code_type',
            "attributes": {
              "additional_code_type_id": String,
              "description": String,
            },
          },
        ],
      }
    end

    it 'returns all additional code types' do
      create(:additional_code_type, :with_description)

      get :index, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end
end
