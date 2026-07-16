require 'swagger_helper'

RSpec.describe 'Headings V3', swagger_doc: 'v3/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.3.0+json' }

  path '/api/v3/headings/{id}' do
    parameter name: :id, in: :path, schema: { type: :string, example: '0101' }, required: true,
              description: 'Four-digit heading code'

    get 'Retrieve a heading' do
      tags 'Headings'
      operationId 'getHeadingV3'

      response '200', 'heading found' do
        schema type: :object,
               required: %w[goods_nomenclature_sid goods_nomenclature_item_id],
               properties: {
                 goods_nomenclature_sid: { type: :integer },
                 goods_nomenclature_item_id: { type: :string, example: '0101000000' },
                 description: { type: :string, nullable: true },
                 formatted_description: { type: :string, nullable: true },
                 validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                 validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                 declarable: { type: :boolean },
               }

        let(:id) { '0101' }

        before { create(:heading, :with_chapter, goods_nomenclature_item_id: '0101000000') }

        run_test!
      end

      response '404', 'heading not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { '9999' }
        run_test!
      end
    end
  end

  path '/api/v3/headings/{id}/commodities' do
    parameter name: :id, in: :path, schema: { type: :string, example: '0101' }, required: true,
              description: 'Four-digit heading code'

    get 'List commodities under a heading' do
      tags 'Headings'
      operationId 'listHeadingCommoditiesV3'

      response '200', 'commodities listed' do
        schema type: :object,
               required: %w[data meta],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       goods_nomenclature_sid: { type: :integer },
                       goods_nomenclature_item_id: { type: :string },
                       producline_suffix: { type: :string, nullable: true },
                       description: { type: :string, nullable: true },
                       formatted_description: { type: :string, nullable: true },
                       number_indents: { type: :integer, nullable: true },
                       validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                       validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                       declarable: { type: :boolean },
                     },
                   },
                 },
                 meta: { '$ref' => '#/components/schemas/meta' },
               }

        let(:id) { '0101' }

        before { create(:heading, :with_chapter, :with_commodities, goods_nomenclature_item_id: '0101000000') }

        run_test!
      end
    end
  end
end
