RSpec.describe Api::V2::AdditionalCodesController, type: :controller do
  describe 'GET #search' do
    let!(:additional_code) { create(:additional_code, :with_description) }

    let(:pattern) do
      {
        data: [
          {
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
          },
        ],
        included: [
          {
            id: String,
            type: 'measure',
            attributes: {
              validity_start_date: String,
              validity_end_date: nil,
              goods_nomenclature_item_id: String,
            },
            relationships: {
              goods_nomenclature: {
                data: {
                  id: String,
                  type: 'heading',
                },
              },
              geographical_area: {
                data: {
                  id: String,
                  type: 'geographical_area',
                },
              },
            },
          },
          {
            id: String,
            type: 'heading',
            attributes: {
              goods_nomenclature_item_id: String,
              description: String,
              formatted_description: String,
              producline_suffix: String,
              validity_start_date: String,
              validity_end_date: nil,
            },
          },
        ],
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
      current_goods_nomenclature = create(:heading)

      create(
        :measure,
        :with_base_regulation,
        additional_code_sid: additional_code.additional_code_sid,
        goods_nomenclature_sid: current_goods_nomenclature.goods_nomenclature_sid,
        goods_nomenclature_item_id: current_goods_nomenclature.goods_nomenclature_item_id,
      )
      create(
        :goods_nomenclature_description,
        goods_nomenclature_sid: current_goods_nomenclature.goods_nomenclature_sid,
      )
      create(
        :measure,
        :with_base_regulation,
        additional_code_sid: additional_code.additional_code_sid,
        goods_nomenclature_sid: nil,
        goods_nomenclature_item_id: nil,
      )
      create(
        :additional_code_description,
        :with_period,
        additional_code_sid: additional_code.additional_code_sid,
      )

      Sidekiq::Testing.inline! do
        TradeTariffBackend.cache_client.reindex(Cache::AdditionalCodeIndex.new)
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
