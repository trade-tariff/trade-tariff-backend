RSpec.describe Api::V2::SearchReferencesController do
  routes { V2Api.routes }

  before do
    TradeTariffRequest.time_machine_now = Time.current

    create :search_reference, :with_heading, title: 'aa'
    create :search_reference, :with_chapter, title: 'bb'
    create :search_reference, :with_commodity, title: 'bb'
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
                negated_title: String,
                referenced_class: 'Commodity',
                referenced_id: String,
                productline_suffix: String,
                goods_nomenclature_item_id: String,
                goods_nomenclature_sid: Integer,
              },
            },
            {
              id: String,
              type: String,
              attributes: {
                title: String,
                negated_title: String,
                referenced_class: 'Chapter',
                referenced_id: String,
                productline_suffix: String,
                goods_nomenclature_item_id: String,
                goods_nomenclature_sid: Integer,
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
