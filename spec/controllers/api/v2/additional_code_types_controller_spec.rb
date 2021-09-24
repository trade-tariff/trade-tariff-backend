RSpec.describe Api::V2::AdditionalCodeTypesController, type: :controller do
  render_views

  describe '#index' do
    let!(:additional_code_type_1) { create :additional_code_type }
    let!(:additional_code_type_description_1) { create :additional_code_type_description, additional_code_type_id: additional_code_type_1.additional_code_type_id }
    let!(:additional_code_type_2) { create :additional_code_type }
    let!(:additional_code_type_description_2) { create :additional_code_type_description, additional_code_type_id: additional_code_type_2.additional_code_type_id }
    let!(:additional_code_type_3) { create :additional_code_type }
    let!(:additional_code_type_description_3) { create :additional_code_type_description, additional_code_type_id: additional_code_type_3.additional_code_type_id }

    let(:pattern) do
      {
        "data": [{
          "id": String,
          "type": 'additional_code_type',
          "attributes": {
            "additional_code_type_id": String,
            "description": String,
          },
        },
                 {
                   "id": String,
                   "type": 'additional_code_type',
                   "attributes": {
                     "additional_code_type_id": String,
                     "description": String,
                   },
                 },
                 {
                   "id": String,
                   "type": 'additional_code_type',
                   "attributes": {
                     "additional_code_type_id": String,
                     "description": String,
                   },
                 }],
      }
    end

    it 'returns all additional code types' do
      get :index, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end
end
