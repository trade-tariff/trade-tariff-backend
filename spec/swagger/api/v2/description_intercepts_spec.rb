require 'swagger_helper'

RSpec.describe 'Description Intercepts', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/description_intercepts' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :source, in: :query, required: false,
              schema: { type: :string },
              description: 'Filter by an enabled description intercept source'
    parameter name: :excluded, in: :query, required: false,
              schema: { type: :boolean },
              description: 'Filter by whether the intercept excludes the term'

    get 'List description intercepts' do
      tags 'Description Intercepts'
      produces 'application/json'
      description 'Returns description intercepts, optionally filtered by source and excluded state.'
      operationId 'listDescriptionIntercepts'

      response '200', 'description intercepts listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[description_intercept] },
                       attributes: {
                         type: :object,
                         properties: {
                           term: { type: :string, nullable: true },
                           sources: { type: :array, items: { type: :string }, nullable: true },
                           message: { type: :string, nullable: true },
                           excluded: { type: :boolean, nullable: true },
                           created_at: { type: :string, format: :'date-time', nullable: true },
                           updated_at: { type: :string, format: :'date-time', nullable: true },
                           guidance_level: { type: :string, nullable: true },
                           guidance_location: { type: :string, nullable: true },
                           escalate_to_webchat: { type: :boolean, nullable: true },
                           filter_prefixes: { type: :array, items: { type: :string }, nullable: true },
                         },
                       },
                     },
                   },
                 },
               }

        before { create(:description_intercept, sources: Sequel.pg_array(%w[fpo_search], :text), excluded: true) }

        run_test!
      end
    end
  end
end
