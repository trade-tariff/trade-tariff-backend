require 'swagger_helper'

RSpec.describe 'Simplified Procedural Code Measures', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/uk/api/simplified_procedural_code_measures' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: 'filter[simplified_procedural_code]', in: :query, required: false,
              schema: { type: :string },
              description: 'Filter by simplified procedural code (e.g. "2.120.1")'
    parameter name: 'filter[from_date]', in: :query, required: false,
              schema: { type: :string, format: 'date' },
              description: 'Filter measures valid from this date (inclusive)'
    parameter name: 'filter[to_date]', in: :query, required: false,
              schema: { type: :string, format: 'date' },
              description: 'Filter measures valid up to this date (inclusive)'

    get 'List simplified procedural code measures' do
      tags 'Simplified Procedural Codes'
      produces 'application/json'
      description 'Returns measures associated with simplified procedural codes. Without a code filter, returns all codes merged with null measures.'
      operationId 'listSimplifiedProceduralCodeMeasures'

      response '200', 'simplified procedural code measures listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[simplified_procedural_code_measure] },
                       attributes: {
                         type: :object,
                         properties: {
                           simplified_procedural_code: { type: :string, nullable: true },
                           goods_nomenclature_item_id: { type: :string, nullable: true },
                           goods_nomenclature_label: { type: :string, nullable: true },
                           validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                           validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                         },
                       },
                     },
                   },
                 },
               }

        run_test!
      end
    end
  end
end
