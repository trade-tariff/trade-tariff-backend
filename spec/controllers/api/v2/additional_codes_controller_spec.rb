describe Api::V2::AdditionalCodesController, type: :controller do
  render_views

  context 'additional codes search' do
    let!(:additional_code) { create :additional_code }
    let!(:additional_code_description) { create :additional_code_description, :with_period, additional_code_sid: additional_code.additional_code_sid }
    let!(:measure) { create :measure, additional_code_sid: additional_code.additional_code_sid }
    let!(:goods_nomenclature) { measure.goods_nomenclature }
    let!(:goods_nomenclature_description) { create :goods_nomenclature_description, goods_nomenclature_sid: goods_nomenclature.goods_nomenclature_sid }

    let(:pattern) do
      {
        data: [{
          id: String,
          type: 'additional_code',
          attributes: {
            additional_code_type_id: String,
            additional_code: String,
            code: String,
            description: String,
            formatted_description: String,
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
          },
        }],
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
                     id: String,
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

    before do
      Sidekiq::Testing.inline! do
        TradeTariffBackend.cache_client.reindex
        sleep(1)
      end
    end

    it 'returns rendered found additional codes and related measures and goods nomenclatures searching by additional_code' do
      get :search, params: { code: additional_code.additional_code }, format: :json

      expect(response.body).to match_json_expression pattern
    end

    it 'returns rendered found additional codes and related measures and goods nomenclatures searching by description' do
      get :search, params: { description: additional_code.description }, format: :json

      expect(response.body).to match_json_expression pattern
    end

    it 'returns rendered found additional codes and related measures and goods nomenclatures searching by type' do
      get :search, params: { type: additional_code.additional_code_type_id }, format: :json

      expect(response.body).to match_json_expression pattern
    end
  end
end
