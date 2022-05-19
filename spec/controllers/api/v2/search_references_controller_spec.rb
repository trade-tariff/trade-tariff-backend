RSpec.describe Api::V2::SearchReferencesController do
  before do
    create :search_reference, referenced: create(:heading), title: 'aa'
    create :search_reference, referenced: create(:chapter), title: 'bb'
    create :search_reference, referenced: create(:commodity), title: 'bb'
  end

  describe '#index' do
    context 'with letter param provided' do
      let(:pattern) do
        {
          data: [
            {
              id: String,
              type: String,
              attributes: {
                title: String,
                referenced_class: 'Commodity',
                referenced_id: String,
                productline_suffix: String,
              },
            },
            {
              id: String,
              type: String,
              attributes: {
                title: String,
                referenced_class: 'Chapter',
                referenced_id: String,
                productline_suffix: String,
              },
            },
          ],
        }
      end

      it 'performs lookup with provided letter' do
        get :index, params: { query: { letter: 'b' } }, format: :json

        expect(response.body).to match_json_expression pattern
      end
    end

    context 'with no letter param provided' do
      it 'does not filter by letter' do
        get :index, format: :json

        ref_count = JSON.parse(response.body)['data'].count
        expect(ref_count).to eq(3)
      end
    end
  end
end
