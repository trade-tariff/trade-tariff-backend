require 'swagger_helper'

RSpec.describe 'Goods Nomenclatures', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  goods_nomenclature_item_schema = {
    type: :object,
    properties: {
      id: { type: :string },
      type: { type: :string, enum: %w[goods_nomenclature] },
      attributes: {
        type: :object,
        properties: {
          goods_nomenclature_item_id: { type: :string },
          goods_nomenclature_sid: { type: :integer },
          producline_suffix: { type: :string, nullable: true },
          description: { type: :string, nullable: true },
          number_indents: { type: :integer, nullable: true },
          href: { type: :string, nullable: true },
          formatted_description: { type: :string, nullable: true },
          validity_start_date: { type: :string, nullable: true, format: 'date-time' },
          validity_end_date: { type: :string, nullable: true, format: 'date-time' },
          declarable: { type: :boolean },
        },
      },
      relationships: {
        type: :object,
        properties: {
          parent: {
            type: :object,
            properties: {
              data: {
                type: :object,
                nullable: true,
                properties: {
                  id: { type: :string },
                  type: { type: :string, enum: %w[goods_nomenclature] },
                },
              },
            },
          },
        },
      },
    },
  }.freeze

  path '/uk/api/goods_nomenclatures/{id}' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :id, in: :path, required: true,
              schema: { type: :string, pattern: '^\d{4,10}$' },
              description: 'Goods nomenclature SID (4–10 digits)'

    get 'Retrieve a goods nomenclature by id' do
      tags 'Goods Nomenclatures'
      produces 'application/json'
      description 'Returns a single goods nomenclature item by its SID.'
      operationId 'getGoodsNomenclature'

      response '200', 'goods nomenclature found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: goods_nomenclature_item_schema,
               }

        let(:commodity) { create(:commodity, :with_description) }
        let(:id) { commodity.goods_nomenclature_item_id }

        run_test!
      end

      response '404', 'goods nomenclature not found' do
        let(:id) { '9999' }

        run_test!
      end
    end
  end

  path '/uk/api/goods_nomenclatures/section/{position}' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :position, in: :path, required: true,
              schema: { type: :integer },
              description: 'Section position number'

    get 'List goods nomenclatures for a section' do
      tags 'Goods Nomenclatures'
      produces 'application/json'
      description 'Returns all goods nomenclature items belonging to a section.'
      operationId 'getGoodsNomenclatureBySection'

      response '200', 'goods nomenclatures listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: goods_nomenclature_item_schema,
                 },
               }

        let(:section) { create(:section, :with_chapter) }
        let(:position) { section.position }

        run_test!
      end
    end
  end

  path '/uk/api/goods_nomenclatures/chapter/{chapter_id}' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :chapter_id, in: :path, required: true,
              schema: { type: :string, pattern: '^\d{2}$' },
              description: 'Chapter short code (2 digits, e.g. "01")'

    get 'List goods nomenclatures for a chapter' do
      tags 'Goods Nomenclatures'
      produces 'application/json'
      description 'Returns all goods nomenclature items belonging to a chapter.'
      operationId 'getGoodsNomenclatureByChapter'

      response '200', 'goods nomenclatures listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: goods_nomenclature_item_schema,
                 },
               }

        let(:chapter) { create(:chapter, :with_description) }
        let(:chapter_id) { chapter.goods_nomenclature_item_id.first(2) }

        run_test!
      end
    end
  end

  path '/uk/api/goods_nomenclatures/heading/{heading_id}' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :heading_id, in: :path, required: true,
              schema: { type: :string, pattern: '^\d{4}$' },
              description: 'Heading code (4 digits, e.g. "0101")'

    get 'List goods nomenclatures for a heading' do
      tags 'Goods Nomenclatures'
      produces 'application/json'
      description 'Returns all goods nomenclature items belonging to a heading.'
      operationId 'getGoodsNomenclatureByHeading'

      response '200', 'goods nomenclatures listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: goods_nomenclature_item_schema,
                 },
               }

        let(:heading) { create(:heading, :with_description) }
        let(:heading_id) { heading.goods_nomenclature_item_id.first(4) }

        run_test!
      end
    end
  end
end
