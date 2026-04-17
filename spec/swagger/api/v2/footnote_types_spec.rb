require 'swagger_helper'

RSpec.describe 'Footnote Types', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/footnote_types' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'

    get 'List all footnote types' do
      tags 'Footnotes'
      produces 'application/json'
      description 'Returns all footnote types with their descriptions.'
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
                       id: { type: :string },
                       type: { type: :string, enum: %w[footnote_type] },
                       attributes: {
                         type: :object,
                         properties: {
                           footnote_type_id: { type: :string, nullable: true },
                           description: { type: :string, nullable: true },
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
    end
  end
end
