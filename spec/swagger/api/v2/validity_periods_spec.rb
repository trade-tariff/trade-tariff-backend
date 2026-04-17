require 'swagger_helper'

RSpec.describe 'Validity Periods', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  validity_period_item_schema = {
    type: :object,
    properties: {
      id: { type: :string },
      type: { type: :string, enum: %w[validity_period] },
      attributes: {
        type: :object,
        properties: {
          goods_nomenclature_item_id: { type: :string },
          producline_suffix: { type: :string, nullable: true },
          validity_start_date: { type: :string, nullable: true, format: 'date-time' },
          validity_end_date: { type: :string, nullable: true, format: 'date-time' },
          description: { type: :string, nullable: true },
          formatted_description: { type: :string, nullable: true },
          to_param: { type: :string, nullable: true },
        },
      },
      relationships: {
        type: :object,
        properties: {
          deriving_goods_nomenclatures: {
            type: :object,
            properties: {
              data: {
                type: :array,
                items: { type: :object },
              },
            },
          },
        },
      },
    },
  }.freeze

  path '/uk/api/headings/{heading_id}/validity_periods' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :heading_id, in: :path, required: true,
              schema: { type: :string, pattern: '^\d{4}$' },
              description: 'Heading code (exactly 4 digits)'

    get 'List validity periods for a heading' do
      tags 'Validity Periods'
      produces 'application/json'
      description 'Returns all validity periods for a heading.'
      operationId 'listHeadingValidityPeriods'

      response '200', 'validity periods listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: validity_period_item_schema,
                 },
               }

        let(:heading) { create(:heading, :with_description) }
        let(:heading_id) { heading.goods_nomenclature_item_id.first(4) }

        run_test!
      end
    end
  end

  path '/uk/api/subheadings/{subheading_id}/validity_periods' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :subheading_id, in: :path, required: true,
              schema: { type: :string, pattern: '^\d{10}-\d{2}$' },
              description: 'Subheading id in the format "{10-digit-code}-{producline_suffix}"'

    get 'List validity periods for a subheading' do
      tags 'Validity Periods'
      produces 'application/json'
      description 'Returns all validity periods for a subheading.'
      operationId 'listSubheadingValidityPeriods'

      response '200', 'validity periods listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: validity_period_item_schema,
                 },
               }

        let(:subheading) { create(:subheading, :with_description) }
        let(:subheading_id) { "#{subheading.goods_nomenclature_item_id}-#{subheading.producline_suffix}" }

        run_test!
      end
    end
  end

  path '/uk/api/commodities/{commodity_id}/validity_periods' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :commodity_id, in: :path, required: true,
              schema: { type: :string, pattern: '^\d{10}$' },
              description: 'Commodity code (exactly 10 digits)'

    get 'List validity periods for a commodity' do
      tags 'Validity Periods'
      produces 'application/json'
      description 'Returns all validity periods for a commodity.'
      operationId 'listCommodityValidityPeriods'

      response '200', 'validity periods listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: validity_period_item_schema,
                 },
               }

        let(:commodity) { create(:commodity, :with_description, :declarable) }
        let(:commodity_id) { commodity.goods_nomenclature_item_id }

        run_test!
      end
    end
  end
end
