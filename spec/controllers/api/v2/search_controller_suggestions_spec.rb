RSpec.describe Api::V2::SearchController do
  describe 'GET /search_suggestions' do
    subject(:response) { get :suggestions, params: params }

    let(:params) { {} }

    let!(:included_commodity) { create :commodity }

    let(:pattern) { { data: [{ id: String, type: 'search_suggestion', attributes: { value: String } }] } }

    it { expect(response.body).to match_json_expression pattern }
    it { expect(response.body.to_s).to include(included_commodity.goods_nomenclature_item_id) }

    context 'when as_of is specified' do
      let(:params) { { as_of: '2015-12-04' } }

      before do
        create(
          :commodity,
          goods_nomenclature_item_id: '0101010000',
          validity_end_date: '2015-12-31', # Included
          validity_start_date: '2000-12-31',
        )

        create(
          :commodity,
          goods_nomenclature_item_id: '0101020000',
          validity_end_date: '2015-12-01', # Excluded
          validity_start_date: '2000-12-31',
        )
      end

      it { expect(response.body.to_s).to include('0101010000') }
      it { expect(response.body.to_s).not_to include('0101020000') }
    end

    context 'when there are search_references' do
      before { create :search_reference, referenced: create(:heading), title: 'foo' }

      it { expect(response.body.to_s).to include('foo') }
    end
  end
end
