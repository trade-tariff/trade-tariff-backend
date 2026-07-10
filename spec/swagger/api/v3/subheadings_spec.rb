require 'swagger_helper'

RSpec.describe 'Subheadings V3', swagger_doc: 'v3/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.3.0+json' }

  path '/api/v3/subheadings/{id}' do
    parameter name: :id, in: :path, schema: { type: :string, example: '0101210000' }, required: true,
              description: 'Ten-digit goods nomenclature item ID for a non-declarable subheading'

    get 'Retrieve a subheading' do
      tags 'Subheadings'
      produces 'application/json'
      operationId 'getSubheadingV3'

      response '200', 'subheading found' do
        schema type: :object,
               required: %w[goods_nomenclature_sid goods_nomenclature_item_id],
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
               }

        let(:id) { '0101210000' }

        before { create(:subheading, :with_description, goods_nomenclature_item_id: '0101210000') }

        run_test!
      end

      response '404', 'subheading not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { '9999999999' }
        run_test!
      end
    end
  end

  path '/api/v3/subheadings/{id}/commodities' do
    parameter name: :id, in: :path, schema: { type: :string, example: '0101210000' }, required: true,
              description: 'Ten-digit subheading item ID'

    get 'List commodities under a subheading' do
      tags 'Subheadings'
      produces 'application/json'
      operationId 'listSubheadingCommoditiesV3'

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

        let(:id) { '0101210000' }

        before { create(:subheading, :with_description, :with_commodities, goods_nomenclature_item_id: '0101210000') }

        run_test!
      end
    end
  end
end
