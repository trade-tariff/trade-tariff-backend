require 'swagger_helper'

RSpec.describe 'Footnotes', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/footnotes/search' do
    parameter '$ref' => '#/components/parameters/accept_header'
    parameter name: :description, in: :query, required: false,
              schema: { type: :string },
              description: 'Retrieve footnotes with description that contains description. Can be combined with `type` and `code`.'
    parameter name: :type, in: :query, required: false,
              schema: { type: :string },
              description: 'Filter by footnote type ID. Must be combined with a `code`.'
    parameter name: :code, in: :query, required: false,
              schema: { type: :string },
              description: 'Filter by footnote code. Must be combined with `type`.'

    get 'Search footnotes' do
      tags 'Footnotes'
      produces 'application/json'
      jsonapi_query_parameters(includes: %w[goods_nomenclatures])
      description 'Returns footnotes matching the search parameters, including related goods nomenclatures.'
      operationId 'searchFootnotes'

      response '200', 'footnotes found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[footnote] },
                       attributes: {
                         type: :object,
                         properties: {
                           code: { type: :string, nullable: true },
                           footnote_type_id: { type: :string, nullable: true },
                           footnote_id: { type: :string, nullable: true },
                           description: { type: :string, nullable: true },
                           formatted_description: { type: :string, nullable: true },
                           validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                           validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                         },
                       },

                       relationships: {
                         type: :object,
                         properties: {
                           goods_nomenclatures: {
                             type: :object,
                             description: 'Goods nomenclature records (chapters, headings, commodities, subheadings) associated with this footnote.',
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

      response '422', 'invalid search params — description required when type and code are blank' do
        schema '$ref' => '#/components/schemas/JsonApiErrorResponse'

        let(:description) { nil }
        let(:type) { nil }
        let(:code) { nil }

        run_test!
      end
    end
  end
end
