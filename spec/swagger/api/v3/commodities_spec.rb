require 'swagger_helper'

RSpec.describe 'Commodities V3', swagger_doc: 'v3/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.3.0+json' }

  path '/api/v3/commodities/{id}' do
    parameter name: :id, in: :path, schema: { type: :string, example: '0101210010' }, required: true,
              description: 'Ten-digit commodity code'

    get 'Retrieve a commodity' do
      tags 'Commodities'
      produces 'application/json'
      operationId 'getCommodityV3'

      response '200', 'commodity found' do
        schema type: :object,
               required: %w[goods_nomenclature_sid goods_nomenclature_item_id declarable],
               properties: {
                 goods_nomenclature_sid: { type: :integer },
                 goods_nomenclature_item_id: { type: :string },
                 producline_suffix: { type: :string, nullable: true },
                 description: { type: :string, nullable: true },
                 formatted_description: { type: :string, nullable: true },
                 description_plain: { type: :string, nullable: true },
                 number_indents: { type: :integer, nullable: true },
                 bti_url: { type: :string, nullable: true },
                 consigned_from: { type: :string, nullable: true },
                 validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                 validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                 has_chemicals: { type: :boolean },
                 declarable: { type: :boolean },
               }

        let(:id) { '0101210010' }

        before { create(:commodity, :with_chapter, :with_heading, goods_nomenclature_item_id: '0101210010') }

        run_test!
      end

      response '404', 'commodity not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { '9999999999' }
        run_test!
      end
    end
  end

  path '/api/v3/commodities/{id}/measures' do
    parameter name: :id, in: :path, schema: { type: :string, example: '0101210010' }, required: true,
              description: 'Ten-digit commodity code'

    get 'List measures on a commodity' do
      tags 'Commodities'
      produces 'application/json'
      operationId 'listCommodityMeasuresV3'
      description 'Returns import and export measures applicable to this commodity on the current date. Use ?as_of=YYYY-MM-DD for a historic date.'

      parameter name: :as_of, in: :query, schema: { type: :string, format: :date },
                required: false, description: 'Date to evaluate measures against (ISO 8601). Defaults to today.'

      response '200', 'measures listed' do
        schema type: :object,
               required: %w[import_measures export_measures meta],
               properties: {
                 import_measures: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :integer },
                       effective_start_date: { type: :string, nullable: true, format: 'date-time' },
                       effective_end_date: { type: :string, nullable: true, format: 'date-time' },
                       excise: { type: :boolean },
                       vat: { type: :boolean },
                       reduction_indicator: { type: :integer, nullable: true },
                       measure_type_id: { type: :string },
                       geographical_area_id: { type: :string },
                       additional_code: { type: :string, nullable: true },
                       order_number: { type: :string, nullable: true },
                     },
                   },
                 },
                 export_measures: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :integer },
                       effective_start_date: { type: :string, nullable: true, format: 'date-time' },
                       effective_end_date: { type: :string, nullable: true, format: 'date-time' },
                       excise: { type: :boolean },
                       vat: { type: :boolean },
                       reduction_indicator: { type: :integer, nullable: true },
                       measure_type_id: { type: :string },
                       geographical_area_id: { type: :string },
                       additional_code: { type: :string, nullable: true },
                       order_number: { type: :string, nullable: true },
                     },
                   },
                 },
                 meta: { '$ref' => '#/components/schemas/meta' },
               }

        let(:id) { '0101210010' }

        before { create(:commodity, :with_chapter, :with_heading, :with_measures, goods_nomenclature_item_id: '0101210010') }

        run_test!
      end
    end
  end
end
