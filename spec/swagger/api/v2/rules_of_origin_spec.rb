require 'swagger_helper'

RSpec.describe 'Rules of Origin', swagger_doc: 'v2/swagger.json', type: :request do
  include_context 'with fake global rules of origin data'

  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  scheme_item_schema = {
    type: :object,
    properties: {
      id: { type: :string },
      type: { type: :string, enum: %w[rules_of_origin_scheme] },
      attributes: {
        type: :object,
        properties: {
          scheme_code: { type: :string, nullable: true },
          title: { type: :string, nullable: true },
          countries: {
            type: :array,
            nullable: true,
            items: { type: :string },
          },
        },
      },
    },
  }.freeze

  path '/api/rules_of_origin_schemes' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'

    get 'List all rules of origin schemes' do
      tags 'Rules of Origin'
      produces 'application/json'
      description 'Returns all rules of origin schemes with their links and origin reference documents.'
      operationId 'listRulesOfOriginSchemes'

      response '200', 'schemes listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: scheme_item_schema,
                 },
               }

        run_test!
      end
    end
  end

  path '/api/rules_of_origin_schemes/{heading_code}/{country_code}' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :heading_code, in: :path, required: true,
              schema: { type: :string },
              description: 'Heading code (e.g. "0101")'
    parameter name: :country_code, in: :path, required: true,
              schema: { type: :string },
              description: 'ISO 2-letter country code (e.g. "TR")'

    get 'List rules of origin schemes for a heading and country' do
      tags 'Rules of Origin'
      produces 'application/json'
      description 'Returns rules of origin schemes applicable to a heading/country combination, including rules, articles, and proofs.'
      operationId 'getRulesOfOriginForHeading'

      response '200', 'schemes found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: scheme_item_schema,
                 },
               }

        let(:heading_code) { roo_heading_code }
        let(:country_code) { roo_country_code }

        run_test!
      end
    end
  end

  path '/api/rules_of_origin_schemes/{commodity_code}' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :commodity_code, in: :path, required: true,
              schema: { type: :string, pattern: '^\d{6,10}$' },
              description: 'Commodity code (6–10 digits, e.g. "0101210000")'

    get 'List product-specific rules for a commodity' do
      tags 'Rules of Origin'
      produces 'application/json'
      description 'Returns all rules of origin schemes with product-specific rule sets filtered to the given commodity code.'
      operationId 'getProductSpecificRules'

      response '200', 'product specific rules found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: scheme_item_schema,
                 },
               }

        # Use the heading code from the fake dataset as a valid commodity prefix
        let(:commodity_code) { "#{roo_heading_code}000000" }

        run_test!
      end
    end
  end
end
