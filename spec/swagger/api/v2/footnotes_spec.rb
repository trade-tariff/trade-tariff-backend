require 'swagger_helper'

RSpec.describe 'Footnotes', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/uk/api/footnotes/search' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :description, in: :query, required: false,
              schema: { type: :string },
              description: 'Filter by footnote description (partial match)'
    parameter name: :type, in: :query, required: false,
              schema: { type: :string },
              description: 'Filter by footnote type ID'
    parameter name: :code, in: :query, required: false,
              schema: { type: :string },
              description: 'Filter by footnote code'

    get 'Search footnotes' do
      tags 'Footnotes'
      produces 'application/json'
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
                     },
                   },
                 },
               }

        let(:description) { 'test' }

        run_test!
      end
    end
  end
end
