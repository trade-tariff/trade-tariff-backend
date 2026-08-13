require 'swagger_helper'

RSpec.describe 'Categorisation Themes', swagger_doc: 'v2/swagger.json', type: :request do
  let(:accept) { 'application/vnd.hmrc.2.0+json' }

  before { allow(TradeTariffBackend).to receive(:uk?).and_return(false) }

  theme_schema = {
    type: :object,
    required: %w[id type attributes],
    properties: {
      id: { type: :string, description: 'Theme code, formatted as "{section}.{subsection}".' },
      type: { type: :string, enum: %w[theme] },
      attributes: {
        type: :object,
        properties: {
          section: { type: :string, description: 'Same value as `id`.' },
          theme: { type: :string, description: 'Theme description.' },
          category: { type: :integer, description: 'Category assessment risk category (1, 2, or 3).' },
        },
      },
    },
  }.freeze

  path '/api/categorisation/themes' do
    parameter '$ref' => '#/components/parameters/accept_header'

    get 'List Categorisation themes' do
      tags 'Categorisation'
      security [{ oauth2_client_credentials: ['tariff/categorisation'] }]
      produces 'application/json'
      description 'Returns all Categorisation (Green Lanes) themes, ordered by section and subsection. ' \
                   'Available on the Northern Ireland (XI) service only.'
      operationId 'getCategorisationThemes'

      response '200', 'themes listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: theme_schema,
                 },
               }

        before { create(:green_lanes_theme) }

        run_test!
      end
    end
  end
end
