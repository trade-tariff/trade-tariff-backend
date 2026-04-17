require 'swagger_helper'

RSpec.describe 'Preference Codes', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  preference_code_item_schema = {
    type: :object,
    properties: {
      id: { type: :string },
      type: { type: :string, enum: %w[preference_code] },
      attributes: {
        type: :object,
        properties: {
          code: { type: :string, nullable: true },
          description: { type: :string, nullable: true },
        },
      },
    },
  }.freeze

  path '/api/preference_codes' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'

    get 'List all preference codes' do
      tags 'Preference Codes'
      produces 'application/json'
      description 'Returns all preference codes loaded from the preference codes reference file.'
      operationId 'listPreferenceCodes'

      response '200', 'preference codes listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: preference_code_item_schema,
                 },
               }

        run_test!
      end
    end
  end

  path '/api/preference_codes/{id}' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :id, in: :path, required: true,
              schema: { type: :string },
              description: 'Preference code (e.g. "100", "400")'

    get 'Retrieve a preference code' do
      tags 'Preference Codes'
      produces 'application/json'
      description 'Returns a single preference code by its code value.'
      operationId 'getPreferenceCode'

      response '200', 'preference code found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: preference_code_item_schema,
               }

        # Preference codes are loaded from data/preference_codes.json — no factory required.
        let(:id) { '100' }

        run_test!
      end

      response '404', 'preference code not found' do
        let(:id) { '999' }

        run_test!
      end
    end
  end
end
