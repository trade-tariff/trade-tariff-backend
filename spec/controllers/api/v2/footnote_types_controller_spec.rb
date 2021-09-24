RSpec.describe Api::V2::FootnoteTypesController, type: :controller do
  render_views

  describe '#index' do
    let!(:footnote_type_1) { create :footnote_type }
    let!(:footnote_type_description_1) { create :footnote_type_description, footnote_type_id: footnote_type_1.footnote_type_id }
    let!(:footnote_type_2) { create :footnote_type }
    let!(:footnote_type_description_2) { create :footnote_type_description, footnote_type_id: footnote_type_2.footnote_type_id }
    let!(:footnote_type_3) { create :footnote_type }
    let!(:footnote_type_description_3) { create :footnote_type_description, footnote_type_id: footnote_type_3.footnote_type_id }

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

    it 'returns all footnote types' do
      get :index, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end
end
