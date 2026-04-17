require 'swagger_helper'

RSpec.describe 'Subheadings', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/subheadings/{id}' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :id, in: :path, required: true,
              schema: { type: :string, pattern: '^\d{10}-\d{2}$' },
              description: 'Subheading id in the format "{10-digit-code}-{producline_suffix}" (e.g. "0101210000-10")'

    get 'Retrieve a subheading' do
      tags 'Subheadings'
      produces 'application/json'
      description 'Returns a single subheading including its commodities, footnotes, and ancestors.'
      operationId 'getSubheading'

      response '200', 'subheading found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :object,
                   required: %w[id type attributes],
                   properties: {
                     id: { type: :string },
                     type: { type: :string, enum: %w[subheading] },
                     attributes: {
                       type: :object,
                       properties: {
                         goods_nomenclature_item_id: { type: :string },
                         goods_nomenclature_sid: { type: :integer },
                         number_indents: { type: :integer, nullable: true },
                         producline_suffix: { type: :string },
                         description: { type: :string, nullable: true },
                         formatted_description: { type: :string, nullable: true },
                         validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                         validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                         description_plain: { type: :string, nullable: true },
                         declarable: { type: :boolean },
                       },
                     },
                     relationships: {
                       type: :object,
                       properties: {
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
                         commodities: {
                           type: :object,
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
                       },
                     },
                   },
                 },
                 included: {
                   type: :array,
                   description: 'Related section, chapter, heading, commodity, footnote, and ancestor objects',
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

        # A subheading must have at least one child in the tree — leaf? raises 404.
        # Build the minimal tree: chapter → heading → subheading (suffix '10') → child commodity (suffix '80').
        before do
          create(:chapter, :with_section, :with_indent, :with_guide,
                 goods_nomenclature_sid: 1, indents: 0,
                 producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX,
                 goods_nomenclature_item_id: '0100000000')
          create(:heading, :with_indent, :with_description,
                 goods_nomenclature_sid: 2, indents: 0,
                 producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX,
                 goods_nomenclature_item_id: '0101000000')
          create(:commodity, :with_indent, :with_description,
                 goods_nomenclature_sid: 3, indents: 1,
                 producline_suffix: '10',
                 goods_nomenclature_item_id: '0101210000')
          create(:commodity, :with_indent, :with_description,
                 goods_nomenclature_sid: 4, indents: 2,
                 producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX,
                 goods_nomenclature_item_id: '0101210000')
        end

        let(:id) { '0101210000-10' }

        run_test!
      end

      response '404', 'subheading not found' do
        let(:id) { '9999999999-80' }

        run_test!
      end
    end
  end
end
