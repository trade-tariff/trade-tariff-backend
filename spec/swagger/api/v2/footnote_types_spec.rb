require 'swagger_helper'

RSpec.describe 'Footnote Types', swagger_doc: 'v2/swagger.json', type: :request do
  let(:accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/footnote_types' do
    parameter name: :Accept, getter: :accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'Accept header for V2 JSON responses. Use `application/vnd.hmrc.2.0+json`.'

    get 'List all footnote types' do
      tags 'Footnotes'
      produces 'application/json'
      jsonapi_query_parameters(includes: [])
      description 'List footnote type IDs used to group footnotes.'
      operationId 'listFootnoteTypes'

      response '200', 'footnote types listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string, description: 'Footnote type ID.' },
                       type: { type: :string, enum: %w[footnote_type], description: 'JSON:API resource type.' },
                       attributes: {
                         type: :object,
                         properties: {
                           footnote_type_id: { type: :string, nullable: true, description: 'Footnote type ID.' },
                           description: { type: :string, nullable: true, description: 'Footnote type description.' },
                         },
                       },
                     },
                   },
                 },
               }

        let(:footnote_type) { create(:footnote_type) }
        before { create(:footnote_type_description, footnote_type_id: footnote_type.footnote_type_id) }

        run_test!
      end

      standard_error_responses
    end
  end
end
