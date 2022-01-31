RSpec.describe Api::V2::SearchReferencesController do
  before do
    create :search_reference, referenced: create(:heading), title: 'aa'
    create :search_reference, referenced: create(:chapter), title: 'bb'
    create :search_reference, referenced: create(:section), title: 'bb'
  end

  context 'with letter param provided' do
    let(:pattern) do
      {
        data: [
          { id: String, type: String, attributes: { title: String, referenced_class: 'Section', referenced_id: String } },
          { id: String, type: String, attributes: { title: String, referenced_class: 'Chapter', referenced_id: String } },
        ],
      }
    end

    it 'performs lookup with provided letter' do
      get :index, params: { query: { letter: 'b' } }, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end

  context 'with no letter param provided' do
    let(:pattern) do
      {
        data: [
          { id: String, type: String, attributes: { title: String, referenced_class: 'Heading', referenced_id: String } },
        ],
      }
    end

    it 'peforms lookup with letter A by default' do
      get :index, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end
end
