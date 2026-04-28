require 'swagger_helper'

RSpec.describe 'Geographical Areas', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  geographical_area_item_schema = {
    type: :object,
    properties: {
      id: { type: :string },
      type: { type: :string, enum: %w[geographical_area] },
      attributes: {
        type: :object,
        properties: {
          id: { type: :string, nullable: true },
          description: { type: :string, nullable: true },
          geographical_area_id: { type: :string, nullable: true },
          geographical_area_sid: { type: :integer, nullable: true },
        },
      },
    },
  }.freeze

  path '/api/geographical_areas' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: 'filter[exclude_none]', in: :query, required: false,
              schema: { type: :boolean },
              description: 'Exclude the "ERGA OMNES (1011)" catch-all area when true'

    get 'List all geographical areas' do
      tags 'Geographical Areas'
      produces 'application/json'
      description 'Returns all geographical areas (countries and groups).'
      operationId 'listGeographicalAreas'

      response '200', 'geographical areas listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: geographical_area_item_schema,
                 },
               }

        before { create(:geographical_area, :with_description, :country) }

        run_test!
      end
    end
  end

  path '/api/geographical_areas/countries' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: 'filter[exclude_none]', in: :query, required: false,
              schema: { type: :boolean },
              description: 'Exclude the "ERGA OMNES (1011)" catch-all area when true'

    get 'List all countries' do
      tags 'Geographical Areas'
      produces 'application/json'
      description 'Returns only country-type geographical areas (geographical_code = "0").'
      operationId 'listCountries'

      response '200', 'countries listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: geographical_area_item_schema,
                 },
               }

        before { create(:geographical_area, :with_description, :country) }

        run_test!
      end
    end
  end

  path '/api/geographical_areas/{id}' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :id, in: :path, required: true,
              schema: { type: :string },
              description: 'Geographical area ID (e.g. "AU", "1011")'

    get 'Retrieve a geographical area' do
      tags 'Geographical Areas'
      produces 'application/json'
      description 'Returns a single geographical area with its contained areas.'
      operationId 'getGeographicalArea'

      response '200', 'geographical area found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     id: { type: :string },
                     type: { type: :string, enum: %w[geographical_area] },
                     attributes: {
                       type: :object,
                       properties: {
                         id: { type: :string, nullable: true },
                         description: { type: :string, nullable: true },
                         geographical_area_id: { type: :string, nullable: true },
                         geographical_area_sid: { type: :integer, nullable: true },
                       },
                     },
                     relationships: {
                       type: :object,
                       properties: {
                         contained_geographical_areas: {
                           type: :object,
                           properties: {
                             data: { type: :array, items: { type: :object } },
                           },
                         },
                       },
                     },
                   },
                 },
               }

        let(:area) { create(:geographical_area, :with_description, :country) }
        let(:id) { area.geographical_area_id }

        run_test!
      end

      response '404', 'geographical area not found' do
        let(:id) { 'NOTFOUND' }

        run_test!
      end
    end
  end
end
