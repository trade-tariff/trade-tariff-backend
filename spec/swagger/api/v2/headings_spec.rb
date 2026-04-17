require 'swagger_helper'

RSpec.describe 'Headings', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/uk/api/headings/{id}' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :id, in: :path, required: true,
              schema: { type: :string, pattern: '^\d{4}$' },
              description: 'Heading code (exactly 4 digits, e.g. "0101")'

    get 'Retrieve a heading' do
      tags 'Headings'
      produces 'application/json'
      description 'Returns a single heading. The response uses either HeadingSerializer (non-declarable) or DeclarableHeadingSerializer (declarable) depending on the heading type.'
      operationId 'getHeading'

      response '200', 'heading found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :object,
                   required: %w[id type attributes],
                   properties: {
                     id: { type: :string },
                     type: { type: :string, enum: %w[heading] },
                     attributes: {
                       type: :object,
                       properties: {
                         goods_nomenclature_item_id: { type: :string },
                         description: { type: :string, nullable: true },
                         bti_url: { type: :string, nullable: true },
                         formatted_description: { type: :string, nullable: true },
                         description_plain: { type: :string, nullable: true },
                         validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                         validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                         declarable: { type: :boolean },
                         producline_suffix: { type: :string, nullable: true },
                         basic_duty_rate: { type: :string, nullable: true },
                         meursing_code: { type: :boolean, nullable: true },
                         has_chemicals: { type: :boolean, nullable: true },
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
                         commodities: {
                           type: :object,
                           nullable: true,
                           properties: {
                             data: {
                               type: :array,
                               items: {
                                 type: :object,
                                 properties: {
                                   id: { type: :string },
                                   type: { type: :string, enum: %w[commodity] },
                                 },
                               },
                             },
                           },
                         },
                       },
                     },
                   },
                 },
                 included: {
                   type: :array,
                   description: 'Related footnote, section, chapter, and commodity objects',
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

        let(:heading) { create(:heading, :with_chapter, :with_description) }
        let(:id) { heading.goods_nomenclature_item_id.first(4) }

        run_test!
      end

      response '404', 'heading not found' do
        let(:id) { '9999' }

        run_test!
      end
    end
  end

  path '/uk/api/headings/{id}/commodities' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :id, in: :path, required: true,
              schema: { type: :string, pattern: '^\d{4}$' },
              description: 'Heading code (exactly 4 digits, e.g. "0101")'

    get 'List commodities for a heading' do
      tags 'Headings'
      produces 'application/json'
      description 'Returns a heading with its full commodity tree.'
      operationId 'listHeadingCommodities'

      response '200', 'commodities listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :object,
                   required: %w[id type attributes],
                   properties: {
                     id: { type: :string },
                     type: { type: :string, enum: %w[heading] },
                     attributes: { type: :object },
                   },
                 },
               }

        let(:heading) { create(:heading, :with_chapter, :with_description) }
        let(:id) { heading.goods_nomenclature_item_id.first(4) }

        run_test!
      end
    end
  end

  path '/uk/api/headings/{id}/changes' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :id, in: :path, required: true,
              schema: { type: :string, pattern: '^\d{4}$' },
              description: 'Heading code (exactly 4 digits, e.g. "0101")'

    get 'List changes for a heading' do
      tags 'Headings'
      produces 'application/json'
      description 'Returns the changelog for a heading.'
      operationId 'listHeadingChanges'

      response '200', 'heading changes listed' do
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

        let(:heading) { create(:heading, :with_description) }
        let(:id) { heading.goods_nomenclature_item_id.first(4) }

        run_test!
      end
    end
  end
end
