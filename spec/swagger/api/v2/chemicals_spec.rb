require 'swagger_helper'

RSpec.describe 'Chemicals', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  chemical_item_schema = {
    type: :object,
    properties: {
      id: { type: :string },
      type: { type: :string, enum: %w[chemical] },
      attributes: {
        type: :object,
        properties: {
          id: { type: :integer, nullable: true },
          cas: { type: :string, nullable: true },
          name: { type: :string, nullable: true },
        },
      },
    },
  }.freeze

  path '/api/chemicals' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'

    get 'List all chemicals' do
      tags 'Chemicals'
      produces 'application/json'
      description 'Returns all chemicals with their CAS numbers and names.'
      operationId 'listChemicals'

      response '200', 'chemicals listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: chemical_item_schema,
                 },
               }

        before { create(:chemical, :with_name) }

        run_test!
      end
    end
  end

  path '/api/chemicals/search' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :name, in: :query, required: false,
              schema: { type: :string },
              description: 'Search by chemical name'
    parameter name: :cas, in: :query, required: false,
              schema: { type: :string },
              description: 'Search by CAS number'
    parameter name: :page, in: :query, required: false,
              schema: { type: :integer },
              description: 'Page number'
    parameter name: :per_page, in: :query, required: false,
              schema: { type: :integer },
              description: 'Results per page'

    get 'Search chemicals' do
      tags 'Chemicals'
      produces 'application/json'
      description 'Returns chemicals matching the search query.'
      operationId 'searchChemicals'

      response '200', 'chemicals found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: chemical_item_schema,
                 },
               }

        let(:chemical) { create(:chemical, :with_name) }
        let(:name) { chemical.chemical_names.first.name }

        run_test!
      end
    end
  end

  path '/api/chemicals/{id}' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :id, in: :path, required: true,
              schema: { type: :string },
              description: 'CAS number (e.g. "22199-08-2")'

    get 'Retrieve a chemical' do
      tags 'Chemicals'
      produces 'application/json'
      description 'Returns a single chemical by its CAS number.'
      operationId 'getChemical'

      response '200', 'chemical found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: chemical_item_schema,
               }

        let(:chemical) { create(:chemical, :with_name) }
        let(:id) { chemical.cas }

        run_test!
      end

      response '404', 'chemical not found' do
        let(:id) { '00-00-0' }

        run_test!
      end
    end
  end
end
