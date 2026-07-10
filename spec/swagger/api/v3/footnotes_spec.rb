require 'swagger_helper'

RSpec.describe 'Footnotes V3', swagger_doc: 'v3/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.3.0+json' }

  path '/api/v3/footnotes' do
    get 'List all footnotes' do
      tags 'Footnotes'
      produces 'application/json'
      operationId 'listFootnotesV3'

      response '200', 'footnotes listed' do
        schema type: :object,
               required: %w[data meta],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       footnote_type_id: { type: :string },
                       footnote_id: { type: :string },
                       description: { type: :string, nullable: true },
                       validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                       validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                     },
                   },
                 },
                 meta: { '$ref' => '#/components/schemas/meta' },
               }

        before { create(:footnote, :with_description) }

        run_test!
      end
    end
  end

  path '/api/v3/footnote_types' do
    get 'List all footnote types' do
      tags 'Footnotes'
      produces 'application/json'
      operationId 'listFootnoteTypesV3'

      response '200', 'footnote types listed' do
        schema type: :object,
               required: %w[data meta],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       footnote_type_id: { type: :string },
                       description: { type: :string, nullable: true },
                       application_code: { type: :integer, nullable: true },
                       validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                       validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                     },
                   },
                 },
                 meta: { '$ref' => '#/components/schemas/meta' },
               }

        before { create(:footnote_type, :with_description) }

        run_test!
      end
    end
  end
end
