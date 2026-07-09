RSpec.describe Api::V2::FootnoteTypesController, type: :request do
  describe '#index' do
    let(:first_footnote_type) { create :footnote_type }
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
    let(:second_footnote_type) { create :footnote_type }
    let(:third_footnote_type) { create :footnote_type }

    before do
      create :footnote_type_description, footnote_type_id: first_footnote_type.footnote_type_id
      create :footnote_type_description, footnote_type_id: second_footnote_type.footnote_type_id
      create :footnote_type_description, footnote_type_id: third_footnote_type.footnote_type_id
    end

    it 'returns all footnote types' do
      get '/uk/api/footnote_types.json', headers: request_headers(format: :json)

      expect(response.body).to match_json_expression pattern
    end
  end
end
