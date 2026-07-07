require 'swagger_helper'

RSpec.describe 'Footnotes', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  search_validation_error_schema = {
    type: :object,
    required: %w[errors],
    properties: {
      errors: {
        type: :array,
        items: {
          type: :object,
          properties: {
            status: { type: :integer, enum: [422], description: 'HTTP status code for the validation error.' },
            title: { type: :string, description: 'Validation message.' },
            detail: { type: :string, description: 'Human-readable validation error detail.' },
          },
        },
      },
    },
  }.freeze

  path '/api/footnotes/search' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'Accept header for V2 JSON responses. Use `application/vnd.hmrc.2.0+json`.'
    parameter name: :description, in: :query, required: false,
              schema: { type: :string },
              description: 'Partial footnote description to search for. Required when `type` and `code` are both omitted.'
    parameter name: :type, in: :query, required: false,
              schema: { type: :string },
              description: 'Footnote type ID. Must be supplied with `code` when used.'
    parameter name: :code, in: :query, required: false,
              schema: { type: :string },
              description: 'Footnote code within the footnote type. Must be supplied with `type` when used.'

    get 'Search footnotes' do
      tags 'Footnotes'
      produces 'application/json'
      jsonapi_query_parameters(includes: %w[goods_nomenclatures])
      description 'Search footnotes attached to goods nomenclature or measures by description, or by type and code together. Results can include related goods nomenclatures.'
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
                       id: { type: :string, description: 'Combined footnote type and footnote code.' },
                       type: { type: :string, enum: %w[footnote], description: 'JSON:API resource type.' },
                       attributes: {
                         type: :object,
                         properties: {
                           code: { type: :string, nullable: true, description: 'Combined footnote type and footnote ID.' },
                           footnote_type_id: { type: :string, nullable: true, description: 'Footnote type ID.' },
                           footnote_id: { type: :string, nullable: true, description: 'Footnote code within the footnote type.' },
                           description: { type: :string, nullable: true, description: 'Footnote description.' },
                           formatted_description: { type: :string, nullable: true, description: 'Footnote description formatted for display.' },
                           validity_start_date: { type: :string, nullable: true, format: 'date-time', description: 'Date and time from which this footnote is valid.' },
                           validity_end_date: { type: :string, nullable: true, format: 'date-time', description: 'Date and time after which this footnote is no longer valid, or null when current.' },
                         },
                       },
                     },
                   },
                 },
               }

        let(:description) { 'test' }

        run_test!
      end

      response '422', 'invalid footnote search parameters' do
        schema search_validation_error_schema

        let(:type) { 'TN' }

        run_test!
      end
    end
  end
end
