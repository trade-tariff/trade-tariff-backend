require 'swagger_helper'

RSpec.describe 'Geographical Areas V3', swagger_doc: 'v3/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.3.0+json' }

  path '/api/v3/geographical_areas' do
    get 'List all geographical areas' do
      tags 'Geographical Areas'
      operationId 'listGeographicalAreasV3'

      response '200', 'areas listed' do
        schema type: :object

        before { create(:geographical_area, :with_description, geographical_area_id: 'GB') }

        run_test!
      end
    end
  end

  path '/api/v3/geographical_areas/{id}' do
    parameter name: :id, in: :path, schema: { type: :string, example: 'GB' }, required: true,
              description: 'Geographical area ID (ISO country code or group ID)'

    get 'Retrieve a geographical area' do
      tags 'Geographical Areas'
      operationId 'getGeographicalAreaV3'

      response '200', 'area found' do
        schema type: :object,
               required: %w[geographical_area_sid geographical_area_id],
               properties: {
                 geographical_area_sid: { type: :integer },
                 geographical_area_id: { type: :string },
                 description: { type: :string, nullable: true },
                 geographical_code: { type: :string, nullable: true },
                 validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                 validity_end_date: { type: :string, nullable: true, format: 'date-time' },
               }

        let(:id) { 'GB' }

        before { create(:geographical_area, :with_description, geographical_area_id: 'GB') }

        run_test!
      end

      response '404', 'area not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { 'ZZ' }
        run_test!
      end
    end
  end
end
