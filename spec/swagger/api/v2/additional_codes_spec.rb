require 'swagger_helper'

RSpec.describe 'Additional Codes', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/additional_codes/search' do
    parameter '$ref' => '#/components/parameters/accept_header'
    parameter name: :description, in: :query, required: false,
              schema: { type: :string },
              description: 'Filter by additional code description (partial match)'
    parameter name: :type, in: :query, required: false,
              schema: { type: :string },
              description: 'Filter by additional code type ID which will be 1-character. Must be passed together with the `code` parameter.'
    parameter name: :code, in: :query, required: false,
              schema: { type: :string },
              description: 'Filter by additional code value which will be a 3-character ID and may also include letters. Must be passed together with the `type` parameter.'

    get 'Search additional codes' do
      tags 'Additional Codes'
      produces 'application/json'
      jsonapi_query_parameters(includes: %w[goods_nomenclatures])
      description 'Returns additional codes matching the search parameters, including related goods nomenclatures.'
      operationId 'searchAdditionalCodes'

      response '200', 'additional codes found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[additional_code] },
                       attributes: {
                         type: :object,
                         properties: {
                           additional_code_type_id: { type: :string, nullable: true, description: '1-character additional code type ID. See `GET /api/additional_code_types` for the corresponding description.' },
                           additional_code: { type: :string, nullable: true, description: 'The 3-character additional code value on its own, without the type ID prefix.' },
                           code: { type: :string, nullable: true, description: 'The full additional code: the 1-character `additional_code_type_id` followed by the 3-character `additional_code`.' },
                           description: { type: :string, nullable: true },
                           formatted_description: { type: :string, nullable: true },
                         },
                       },
                       relationships: {
                         type: :object,
                         properties: {
                           goods_nomenclatures: {
                             type: :object,
                             description: 'Goods nomenclature records (chapters, headings, commodities, subheadings) associated with this additional code.',
                             properties: {
                               data: {
                                 type: :array,
                                 items: {
                                   type: :object,
                                   properties: {
                                     id: { type: :string },
                                     type: { type: :string },
                                   },
                                 },
                               },
                             },
                           },
                         },
                       },
                     },
                   },
                 },
                 included: {
                   type: :array,
                   description: 'Goods nomenclature records included via the `goods_nomenclatures` relationship.',
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string },
                       attributes: { type: :object },
                     },
                   },
                 },
               }

        let(:description) { 'test' }

        run_test!
      end

      response '422', 'invalid search params description required when type and code are blank' do
        schema '$ref' => '#/components/schemas/StandardErrorResponse'

        let(:description) { nil }
        let(:type) { nil }
        let(:code) { nil }

        run_test!
      end

      standard_bad_request_response
      standard_not_found_response
    end
  end
end
