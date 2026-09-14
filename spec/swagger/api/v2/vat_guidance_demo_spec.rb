require 'swagger_helper'

RSpec.describe 'VAT guidance demo', swagger_doc: 'v2/swagger.json', type: :request do
  let(:accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/vat_guidance_demo' do
    parameter name: :Accept, getter: :accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'

    get 'Show the guarded AI-1146 VAT guidance demo artifact' do
      tags 'VAT guidance demo'
      produces 'application/json'
      description 'Returns a non-production projection of the AI-1146 composed VAT guidance routes for an explicitly enabled frontend demo.'
      operationId 'showVatGuidanceDemo'

      response '200', 'demo artifact returned' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :object,
                   required: %w[id type attributes],
                   properties: {
                     id: { type: :string, enum: %w[ai-1146] },
                     type: { type: :string, enum: %w[vat_guidance_demo] },
                     attributes: {
                       type: :object,
                       required: %w[ticket spike_status composed_commodity_journeys notice_journeys],
                       properties: {
                         ticket: { type: :string, enum: %w[AI-1146] },
                         spike_status: { type: :object },
                         composed_commodity_journeys: { type: :array, items: { type: :object } },
                         notice_journeys: { type: :array, items: { type: :object } },
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
