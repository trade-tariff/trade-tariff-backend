require 'swagger_helper'

RSpec.describe 'Search', swagger_doc: 'v2/swagger.json', type: :request do
  search_match_groups_schema = {
    type: :object,
    description: 'Matches grouped into chapters, headings, and commodities.',
    properties: {
      chapters: { type: :array, items: { type: :object, additionalProperties: true } },
      headings: { type: :array, items: { type: :object, additionalProperties: true } },
      commodities: { type: :array, items: { type: :object, additionalProperties: true } },
    },
  }.freeze

  fuzzy_attributes_schema = {
    type: :object,
    required: %w[type goods_nomenclature_match reference_match],
    properties: {
      type: { type: :string, enum: %w[fuzzy_match null_match], description: 'Match type for fuzzy-search or null-search responses.' },
      goods_nomenclature_match: search_match_groups_schema,
      reference_match: search_match_groups_schema,
    },
  }.freeze

  exact_search_data_schema = {
    type: :object,
    required: %w[id type attributes],
    properties: {
      id: { type: :string },
      type: { type: :string, enum: %w[exact_search] },
      attributes: {
        type: :object,
        required: %w[type entry],
        properties: {
          type: { type: :string, enum: %w[exact_match], description: 'Match type for exact-search responses.' },
          entry: {
            type: :object,
            required: %w[endpoint id],
            properties: {
              endpoint: {
                type: :string,
                description: 'Endpoint name for the matched resource, such as `chapters`, `headings`, or `commodities`.',
              },
              id: {
                type: :string,
                description: 'Identifier for the matched resource.',
              },
            },
          },
        },
      },
    },
  }.freeze

  fuzzy_search_data_schema = {
    type: :object,
    required: %w[id type attributes],
    properties: {
      id: { type: :string },
      type: { type: :string, enum: %w[fuzzy_search] },
      attributes: fuzzy_attributes_schema,
    },
  }.freeze

  null_search_data_schema = {
    type: :object,
    required: %w[id type attributes],
    properties: {
      id: { type: :string },
      type: { type: :string, enum: %w[null_search] },
      attributes: fuzzy_attributes_schema,
    },
  }.freeze

  search_response_schema = {
    type: :object,
    required: %w[data],
    properties: {
      data: {
        oneOf: [
          exact_search_data_schema,
          fuzzy_search_data_schema,
          null_search_data_schema,
        ],
      },
    },
  }.freeze

  search_request_schema = {
    type: :object,
    properties: {
      q: {
        type: :string,
        description: 'Search term, such as a goods description, commodity code, chapter or heading code, CAS number, CUS number, or search reference.',
      },
      as_of: {
        type: :string,
        format: :date,
        pattern: '^\\d{4}-\\d{2}-\\d{2}$',
        description: 'Date for the tariff data snapshot, formatted as `YYYY-MM-DD`. Defaults to today when omitted or invalid.',
      },
      request_id: {
        type: :string,
        description: 'Optional request identifier used in search instrumentation.',
      },
      resource_id: {
        type: :string,
        description: 'Optional search suggestion identifier used to narrow exact-match lookup.',
      },
    },
  }.freeze

  path '/api/search' do
    parameter '$ref' => '#/components/parameters/accept_header'

    get 'Search tariff classifications with query parameters' do
      tags 'Search'
      produces 'application/json'
      operationId 'searchTariffClassifications'
      description <<~DESC
        Use this endpoint to search for tariff classifications using a goods description, commodity code,
        chapter or heading code, CAS number, CUS number, or search reference. The response is one of three
        result shapes: exact match, fuzzy matches grouped by tariff level, or null search with empty match groups.
      DESC

      parameter name: :q, in: :query, required: false,
                schema: { type: :string },
                description: 'Search term, such as a goods description, commodity code, chapter or heading code, CAS number, CUS number, or search reference.'
      parameter '$ref' => '#/components/parameters/AsOfDate'
      parameter name: :request_id, in: :query, required: false,
                schema: { type: :string },
                description: 'Optional request identifier used in search instrumentation.'
      parameter name: :resource_id, in: :query, required: false,
                schema: { type: :string },
                description: 'Optional search suggestion identifier used to narrow exact-match lookup.'

      response '200', 'search result returned' do
        schema search_response_schema

        let(:q) { nil }
        let(:as_of) { nil }
        let(:request_id) { nil }
        let(:resource_id) { nil }

        run_test!
      end
    end

    post 'Search tariff classifications with a JSON body' do
      tags 'Search'
      consumes 'application/json'
      produces 'application/json'
      operationId 'postSearchTariffClassifications'
      description <<~DESC
        Use this endpoint to search for tariff classifications using a goods description, commodity code,
        chapter or heading code, CAS number, CUS number, or search reference. Use POST when sending search
        parameters in a JSON request body rather than a query string. The response is one of three result
        shapes: exact match, fuzzy matches grouped by tariff level, or null search with empty match groups.
      DESC

      parameter name: :search_request, in: :body, required: false,
                schema: search_request_schema,
                description: 'JSON request body containing search parameters.'

      response '200', 'search result returned' do
        schema search_response_schema

        let(:chapter) { create(:chapter, goods_nomenclature_item_id: '0100000000') }
        let(:search_request) { { q: '01', as_of: Time.zone.today.iso8601, request_id: 'swagger-search-request' } }

        before do
          create(:search_suggestion, :goods_nomenclature, goods_nomenclature: chapter)
        end

        run_test!
      end
    end
  end
end
