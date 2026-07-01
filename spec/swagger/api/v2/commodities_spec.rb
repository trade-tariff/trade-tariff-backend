require 'swagger_helper'

RSpec.describe 'Commodities', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/commodities/{id}' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'Accept header for V2 JSON responses. Must be `application/vnd.hmrc.2.0+json`.'
    parameter name: :id, in: :path, required: true,
              schema: { type: :string, pattern: '^\d{10}$' },
              description: 'Declarable commodity code, exactly 10 digits with no spaces or punctuation.'
    parameter name: 'filter[geographical_area_id]', in: :query, required: false,
              schema: { type: :string },
              description: 'Optional country or geographical area code used to remove import and export measures that are not relevant to that area.'
    parameter name: 'filter[meursing_additional_code_id]', in: :query, required: false,
              schema: { type: :string },
              description: 'Optional Meursing additional code used when resolving duty components for goods that require Meursing calculations.'

    get 'Retrieve a commodity' do
      tags 'Commodities'
      produces 'application/json'
      jsonapi_query_parameters(includes: JsonapiSwaggerParameters::COMMODITY_INCLUDES)
      description <<~DESC
        Use this endpoint when you already have a 10-digit commodity code and need the commodity record,
        including classification hierarchy, footnotes, import measures, export measures, and duty-related metadata.

        Use the `/uk` server for UK Global Tariff data and the `/xi` server for Northern Ireland data. The same
        commodity code can have different measures, duty rates, restrictions, or related records in each dataset.

        The commodity must be declarable and valid on the requested date. Use search or hierarchy endpoints first
        when you only have a goods description or a partial commodity code.
      DESC
      operationId 'getCommodity'

      response '200', 'commodity found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :object,
                   required: %w[id type attributes],
                   properties: {
                     id: { type: :string, description: 'JSON:API resource identifier for the commodity goods nomenclature record.' },
                     type: { type: :string, enum: %w[commodity] },
                     attributes: {
                       type: :object,
                       properties: {
                         producline_suffix: { type: :string, nullable: true, description: 'Goods nomenclature product-line suffix for this row.' },
                         description: { type: :string, nullable: true, description: 'Commodity description as stored in the tariff dataset.' },
                         number_indents: { type: :integer, nullable: true, description: 'Indentation level in the tariff hierarchy.' },
                         goods_nomenclature_item_id: { type: :string, description: '10-digit commodity code for this goods nomenclature item.' },
                         bti_url: { type: :string, nullable: true, description: 'GOV.UK guidance URL for applying for a Binding Tariff Information decision.' },
                         formatted_description: { type: :string, nullable: true, description: 'Commodity description formatted for display.' },
                         description_plain: { type: :string, nullable: true, description: 'Commodity description with formatting removed.' },
                         consigned: { type: :boolean, nullable: true, description: 'Whether the commodity description identifies goods as consigned from one or more countries.' },
                         consigned_from: { type: :string, nullable: true, description: 'Country or countries extracted from "consigned from" wording in the commodity description.' },
                         basic_duty_rate: { type: :string, nullable: true, description: 'Summary basic third-country duty rate, when one can be derived from applicable import measures.' },
                         meursing_code: { type: :boolean, nullable: true, description: 'Whether Meursing additional code information may be needed for this commodity.' },
                         validity_start_date: { type: :string, nullable: true, format: 'date-time', description: 'Date and time from which this commodity description period is valid.' },
                         validity_end_date: { type: :string, nullable: true, format: 'date-time', description: 'Date and time after which this commodity description period is no longer valid, or null when open-ended.' },
                         has_chemicals: { type: :boolean, nullable: true, description: 'Whether chemical substance records are associated with this commodity.' },
                         declarable: { type: :boolean, description: 'true when this commodity can be declared on a customs declaration.' },
                       },
                     },
                     relationships: {
                       type: :object,
                       properties: {
                         footnotes: {
                           type: :object,
                           description: 'Footnotes linked to the commodity, including legal or usage notes that may affect classification or measures.',
                           properties: {
                             data: {
                               type: :array,
                               items: {
                                 type: :object,
                                 properties: {
                                   id: { type: :string },
                                   type: { type: :string, enum: %w[footnote] },
                                 },
                               },
                             },
                           },
                         },
                         section: {
                           type: :object,
                           description: 'Tariff section containing the commodity.',
                           properties: {
                             data: {
                               type: :object,
                               nullable: true,
                               properties: {
                                 id: { type: :string },
                                 type: { type: :string, enum: %w[section] },
                               },
                             },
                           },
                         },
                         chapter: {
                           type: :object,
                           description: 'Tariff chapter containing the commodity.',
                           properties: {
                             data: {
                               type: :object,
                               nullable: true,
                               properties: {
                                 id: { type: :string },
                                 type: { type: :string, enum: %w[chapter] },
                               },
                             },
                           },
                         },
                         heading: {
                           type: :object,
                           description: 'Tariff heading containing the commodity.',
                           properties: {
                             data: {
                               type: :object,
                               nullable: true,
                               properties: {
                                 id: { type: :string },
                                 type: { type: :string, enum: %w[heading] },
                               },
                             },
                           },
                         },
                         ancestors: {
                           type: :object,
                           description: 'Parent goods nomenclature records in the classification hierarchy.',
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
                         },
                         import_measures: {
                           type: :object,
                           description: 'Import duties, controls, restrictions, quotas, and other import measures applicable to the commodity.',
                           properties: {
                             data: {
                               type: :array,
                               items: {
                                 type: :object,
                                 properties: {
                                   id: { type: :string },
                                   type: { type: :string, enum: %w[measure] },
                                 },
                               },
                             },
                           },
                         },
                         export_measures: {
                           type: :object,
                           description: 'Export controls, restrictions, duties, and other export measures applicable to the commodity.',
                           properties: {
                             data: {
                               type: :array,
                               items: {
                                 type: :object,
                                 properties: {
                                   id: { type: :string },
                                   type: { type: :string, enum: %w[measure] },
                                 },
                               },
                             },
                           },
                         },
                         import_trade_summary: {
                           type: :object,
                           description: 'Summary trade statistics for imports of the commodity, when available.',
                           properties: {
                             data: {
                               type: :object,
                               nullable: true,
                               properties: {
                                 id: { type: :string },
                                 type: { type: :string, enum: %w[import_trade_summary] },
                               },
                             },
                           },
                         },
                       },
                     },
                     meta: {
                       type: :object,
                       nullable: true,
                       properties: {
                         duty_calculator: { type: :object, nullable: true },
                       },
                     },
                   },
                 },
                 included: {
                   type: :array,
                   description: 'Related resources included with the commodity response, such as hierarchy, footnote, measure, duty, geographical area, and quota records.',
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string },
                       attributes: { type: :object },
                     },
                   },
                 },
               }

        let(:commodity) { create(:commodity, :with_indent, :with_chapter_and_heading, :with_description, :declarable) }
        let(:id) { commodity.goods_nomenclature_item_id }

        run_test!
      end

      response '404', 'commodity not found' do
        schema '$ref' => '#/components/schemas/SimpleErrorResponse'

        let(:id) { '9999999999' }

        run_test!
      end
    end
  end

  path '/api/commodities/{id}/changes' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :id, in: :path, required: true,
              schema: { type: :string, pattern: '^\d{10}$' },
              description: 'Commodity code (exactly 10 digits)'

    get 'List changes for a commodity' do
      tags 'Commodities'
      produces 'application/json'
      jsonapi_query_parameters(includes: JsonapiSwaggerParameters::CHANGE_INCLUDES)
      description 'Returns the changelog for a commodity.'
      operationId 'listCommodityChanges'

      response '200', 'commodity changes listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[change] },
                       attributes: {
                         type: :object,
                         properties: {
                           oid: { type: :integer, nullable: true },
                           model_name: { type: :string, nullable: true },
                           operation: { type: :string, nullable: true },
                           operation_date: { type: :string, nullable: true, format: 'date-time' },
                         },
                       },
                       relationships: {
                         type: :object,
                         properties: {
                           record: {
                             type: :object,
                             properties: {
                               data: { type: :object, nullable: true },
                             },
                           },
                         },
                       },
                     },
                   },
                 },
                 included: {
                   type: :array,
                   items: { type: :object },
                 },
               }

        let(:commodity) { create(:commodity, :with_description, :declarable) }
        let(:id) { commodity.goods_nomenclature_item_id }

        run_test!
      end
    end
  end
end
