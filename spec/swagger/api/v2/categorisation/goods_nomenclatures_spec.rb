require 'swagger_helper'

RSpec.describe 'Categorisation Goods Nomenclatures', swagger_doc: 'v2/swagger.json', type: :request do
  let(:accept) { 'application/vnd.hmrc.2.0+json' }

  before { allow(TradeTariffBackend).to receive(:uk?).and_return(false) }

  relationship_schema = {
    type: :object,
    properties: {
      data: {
        type: :array,
        items: {
          type: :object,
          properties: {
            id: { type: :string },
            type: { type: :string },
          },
        },
      },
    },
  }.freeze

  goods_nomenclature_schema = {
    type: :object,
    required: %w[id type attributes],
    properties: {
      id: { type: :string, description: 'Goods nomenclature SID.' },
      type: { type: :string, enum: %w[goods_nomenclature] },
      attributes: {
        type: :object,
        properties: {
          goods_nomenclature_sid: { type: :integer },
          goods_nomenclature_item_id: { type: :string },
          description: { type: :string, nullable: true },
          formatted_description: { type: :string, nullable: true },
          validity_start_date: { type: :string, nullable: true, format: 'date-time' },
          validity_end_date: { type: :string, nullable: true, format: 'date-time' },
          description_plain: { type: :string, nullable: true },
          producline_suffix: { type: :string, nullable: true },
          parent_sid: { type: :integer, nullable: true },
          supplementary_measure_unit: { type: :string, nullable: true },
        },
      },
      relationships: {
        type: :object,
        properties: {
          applicable_category_assessments: relationship_schema,
          descendant_category_assessments: relationship_schema,
          ancestors: relationship_schema,
          descendants: relationship_schema,
          licences: relationship_schema,
        },
      },
    },
  }.freeze

  path '/api/categorisation/goods_nomenclatures/{id}' do
    parameter '$ref' => '#/components/parameters/accept_header'
    parameter name: :id, in: :path, required: true,
              schema: { type: :string, pattern: '^\d{4,10}$' },
              description: 'Goods nomenclature SID (4-10 digits). Available on the Northern Ireland (XI) service only.'
    parameter name: :filter, in: :query, required: false,
              style: :deepObject, explode: true,
              schema: {
                type: :object,
                properties: {
                  geographical_area_id: { type: :string },
                },
              },
              description: 'Optional `filter[geographical_area_id]` to scope applicable category assessments to a geographical area.'

    get 'Retrieve a Categorisation goods nomenclature by id' do
      tags 'Categorisation'
      security [{ oauth2_client_credentials: ['tariff/categorisation'] }]
      produces 'application/json'
      description 'Returns a single goods nomenclature together with its applicable and descendant category ' \
                   'assessments, licences, ancestors, and descendants. Available on the Northern Ireland (XI) service only.'
      operationId 'getCategorisationGoodsNomenclature'

      response '200', 'goods nomenclature found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: goods_nomenclature_schema,
                 included: { type: :array, items: { type: :object } },
               }

        before do
          TradeTariffRequest.time_machine_now = Time.current
          create(:category_assessment, measure: gn.measures.first)
        end

        let(:gn) { create(:goods_nomenclature, :with_measures, goods_nomenclature_item_id: '1234560000') }
        let(:id) { gn.goods_nomenclature_item_id.first(6) }
        let(:filter) { nil }

        run_test!
      end

      response '404', 'goods nomenclature not found' do
        let(:id) { '999999' }
        let(:filter) { nil }

        run_test!
      end
    end
  end
end
