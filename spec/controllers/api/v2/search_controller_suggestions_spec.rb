describe Api::V2::SearchController do
  describe 'GET /search_suggestions' do
    subject(:response) { get :suggestions, params: params }

    let(:params) { {} }

    let!(:included_commodity) { create :commodity }

    let(:pattern) { { data: [{ id: String, type: 'search_suggestion', attributes: { value: String } }] } }

    it { expect(response.body).to match_json_expression pattern }
    it { expect(response.body.to_s).to include(included_commodity.goods_nomenclature_item_id) }

    context 'when as_of is specified' do
      let(:params) { { as_of: '2015-12-04' } }

      let!(:included_commodity) { create :commodity, validity_end_date: '2015-12-31', validity_start_date: '2000-12-31' }
      let!(:excluded_commodity) { create :commodity, validity_end_date: '2015-12-01', validity_start_date: '2000-12-31' }

      it { expect(response.body.to_s).to include(included_commodity.goods_nomenclature_item_id) }
      it { expect(response.body.to_s).not_to include(excluded_commodity.goods_nomenclature_item_id) }
    end

    context 'when there are search_references' do
      let(:heading) { create :heading }
      let!(:search_reference_heading) { create :search_reference, heading: heading, heading_id: heading.to_param, title: 'test heading 1' }

      it { expect(response.body.to_s).to include(search_reference_heading.title) }
    end
  end
end
