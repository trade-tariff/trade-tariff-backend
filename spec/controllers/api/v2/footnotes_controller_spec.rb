RSpec.describe Api::V2::FootnotesController, type: :controller do
  render_views

  context 'footnotes search' do
    let!(:footnote) { create :footnote, :national }
    let!(:footnote_description) { create :footnote_description, :with_period, footnote_type_id: footnote.footnote_type_id, footnote_id: footnote.footnote_id }
    let!(:measure) { create :measure }
    let!(:footnote_association_measure) { create :footnote_association_measure, footnote_type_id: footnote.footnote_type_id, footnote_id: footnote.footnote_id, measure_sid: measure.measure_sid }
    let!(:goods_nomenclature) { measure.goods_nomenclature }
    let!(:goods_nomenclature2) { create :goods_nomenclature }
    let!(:footnote_association_goods_nomenclature) { create :footnote_association_goods_nomenclature, footnote_type: footnote.footnote_type_id, footnote_id: footnote.footnote_id, goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid }
    let!(:footnote_association_goods_nomenclature2) { create :footnote_association_goods_nomenclature, footnote_type: footnote.footnote_type_id, footnote_id: footnote.footnote_id, goods_nomenclature_sid: goods_nomenclature2.goods_nomenclature_sid }
    let!(:goods_nomenclature_description) { create :goods_nomenclature_description, goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid }
    let!(:goods_nomenclature_description2) { create :goods_nomenclature_description, goods_nomenclature_sid: goods_nomenclature2.goods_nomenclature_sid }

    let(:pattern) do
      {
        data: [{
          id: String,
          type: 'footnote',
          attributes: {
            code: String,
            footnote_type_id: String,
            footnote_id: String,
            description: String,
            formatted_description: String,
            extra_large_measures: boolean,
          },
          relationships: {
            measures: {
              data: [
                {
                  id: String,
                  type: 'measure',
                },
              ],
            },
            goods_nomenclatures: {
              data: [
                {
                  id: String,
                  type: 'goods_nomenclature',
                },
                {
                  id: String,
                  type: 'goods_nomenclature',
                },
              ],
            },
          },
        }].ignore_extra_values!,
        included: [{
          id: String,
          type: 'measure',
          attributes: {
            id: Integer,
            validity_start_date: String,
            validity_end_date: String,
            goods_nomenclature_item_id: String,
          },
          relationships: {
            goods_nomenclature: {
              data: {
                id: String,
                type: 'goods_nomenclature',
              },
            },
          },
        },
                   {
                     id: goods_nomenclature.goods_nomenclature_sid.to_s,
                     type: 'goods_nomenclature',
                     attributes: {
                       goods_nomenclature_item_id: String,
                       goods_nomenclature_sid: Integer,
                       description: String,
                       number_indents: Integer,
                       producline_suffix: String,
                     },
                   },
                   {
                     id: goods_nomenclature2.goods_nomenclature_sid.to_s,
                     type: 'goods_nomenclature',
                     attributes: {
                       goods_nomenclature_item_id: String,
                       goods_nomenclature_sid: Integer,
                       description: String,
                       number_indents: Integer,
                       producline_suffix: String,
                     },
                   }],
        meta: {
          pagination: {
            page: Integer,
            per_page: Integer,
            total_count: Integer,
          },
        },
      }
    end

    let(:pattern_empty) do
      {
        data: [],
        included: [],
        meta: {
          pagination: {
            page: Integer,
            per_page: Integer,
            total_count: Integer,
          },
        },
      }
    end

    before do
      Sidekiq::Testing.inline! do
        TradeTariffBackend.cache_client.reindex
        sleep(2) # TODO: need to think about better ES rspec integration
      end
    end

    it 'returns footnotes, related measures, and goods nomenclatures when searching by footnote id' do
      get :search, params: { code: footnote.footnote_id }, format: :json

      expect(response.body).to match_json_expression pattern
    end

    it 'returns footnotes, related measures, and goods nomenclatures when searching by footnote type' do
      get :search, params: { type: footnote.footnote_type_id }, format: :json

      expect(response.body).to match_json_expression pattern
    end

    it 'returns footnotes, related measures, and goods nomenclatures when searching by description' do
      get :search, params: { description: footnote.description }, format: :json

      expect(response.body).to match_json_expression pattern
    end

    it 'returns an empty JSON object if no footnotes are found' do
      get :search, params: { code: 'F-O-O-B-A-R' }, format: :json

      expect(response.body).to match_json_expression pattern_empty
    end
  end
end
