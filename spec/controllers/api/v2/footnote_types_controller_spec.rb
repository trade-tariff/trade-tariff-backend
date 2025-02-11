RSpec.describe Api::V2::FootnoteTypesController, type: :controller do
  routes { V2Api.routes }

  describe '#index' do
    let(:footnote_type_1) { create :footnote_type }
    let(:pattern) do
      {
        "data": [{
          "id": String,
          "type": 'footnote_type',
          "attributes": {
            "footnote_type_id": String,
            "description": String,
          },
        },
                 {
                   "id": String,
                   "type": 'footnote_type',
                   "attributes": {
                     "footnote_type_id": String,
                     "description": String,
                   },
                 },
                 {
                   "id": String,
                   "type": 'footnote_type',
                   "attributes": {
                     "footnote_type_id": String,
                     "description": String,
                   },
                 }],
      }
    end
    let(:footnote_type_2) { create :footnote_type }
    let(:footnote_type_3) { create :footnote_type }

    before do
      create :footnote_type_description, footnote_type_id: footnote_type_1.footnote_type_id
      create :footnote_type_description, footnote_type_id: footnote_type_2.footnote_type_id
      create :footnote_type_description, footnote_type_id: footnote_type_3.footnote_type_id
    end

    it 'returns all footnote types' do
      get :index, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end
end
