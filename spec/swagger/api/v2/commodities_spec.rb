require 'swagger_helper'

RSpec.describe 'Commodities', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/uk/api/commodities/{id}' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :id, in: :path, required: true,
              schema: { type: :string, pattern: '^\d{10}$' },
              description: 'Commodity code (exactly 10 digits)'

    get 'Retrieve a commodity' do
      tags 'Commodities'
      produces 'application/json'
      description 'Returns a single commodity including its measures, footnotes, and ancestors.'
      operationId 'getCommodity'

      response '200', 'commodity found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :object,
                   required: %w[id type attributes],
                   properties: {
                     id: { type: :string },
                     type: { type: :string, enum: %w[commodity] },
                     attributes: {
                       type: :object,
                       properties: {
                         producline_suffix: { type: :string, nullable: true },
                         description: { type: :string, nullable: true },
                         number_indents: { type: :integer, nullable: true },
                         goods_nomenclature_item_id: { type: :string },
                         bti_url: { type: :string, nullable: true },
                         formatted_description: { type: :string, nullable: true },
                         description_plain: { type: :string, nullable: true },
                         consigned: { type: :boolean, nullable: true },
                         consigned_from: { type: :string, nullable: true },
                         basic_duty_rate: { type: :string, nullable: true },
                         meursing_code: { type: :boolean, nullable: true },
                         validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                         validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                         has_chemicals: { type: :boolean, nullable: true },
                         declarable: { type: :boolean },
                       },
                     },
                     relationships: {
                       type: :object,
                       properties: {
                         footnotes: {
                           type: :object,
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
                   description: 'Related footnote, section, chapter, heading, measure, and other objects',
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
        let(:id) { '9999999999' }

        run_test!
      end
    end
  end

  path '/uk/api/commodities/{id}/changes' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :id, in: :path, required: true,
              schema: { type: :string, pattern: '^\d{10}$' },
              description: 'Commodity code (exactly 10 digits)'

    get 'List changes for a commodity' do
      tags 'Commodities'
      produces 'application/json'
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
