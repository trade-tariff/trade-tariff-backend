require 'swagger_helper'

RSpec.describe 'Chemical Substances', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/uk/api/chemical_substances' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: 'filter[cas_rn]', in: :query, required: false,
              schema: { type: :string },
              description: 'Filter by CAS Registry Number'
    parameter name: 'filter[cus]', in: :query, required: false,
              schema: { type: :string },
              description: 'Filter by CUS (Customs Union and Statistics) number'
    parameter name: 'filter[goods_nomenclature_sid]', in: :query, required: false,
              schema: { type: :integer },
              description: 'Filter by goods nomenclature SID'
    parameter name: 'filter[goods_nomenclature_item_id]', in: :query, required: false,
              schema: { type: :string },
              description: 'Filter by goods nomenclature item ID (commodity code)'

    get 'List chemical substances' do
      tags 'Chemicals'
      produces 'application/json'
      description 'Returns chemical substances, optionally filtered by CAS number, CUS, or goods nomenclature.'
      operationId 'listChemicalSubstances'

      response '200', 'chemical substances listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[chemical_substance] },
                       attributes: {
                         type: :object,
                         properties: {
                           cas_rn: { type: :string, nullable: true },
                           cus: { type: :string, nullable: true },
                           goods_nomenclature_item_id: { type: :string, nullable: true },
                           name: { type: :string, nullable: true },
                         },
                       },
                     },
                   },
                 },
               }

        before { create(:full_chemical) }

        run_test!
      end
    end
  end
end
