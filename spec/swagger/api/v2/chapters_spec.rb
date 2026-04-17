require 'swagger_helper'

RSpec.describe 'Chapters', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/chapters' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'

    get 'List all chapters' do
      tags 'Chapters'
      produces 'application/json'
      description 'Returns all chapters of the tariff.'
      operationId 'listChapters'

      response '200', 'chapters listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     required: %w[id type attributes],
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[chapter] },
                       attributes: {
                         type: :object,
                         properties: {
                           goods_nomenclature_sid: { type: :integer },
                           goods_nomenclature_item_id: { type: :string },
                           formatted_description: { type: :string, nullable: true },
                         },
                       },
                     },
                   },
                 },
               }

        before { create(:chapter, :with_description) }

        run_test!
      end
    end
  end

  path '/api/chapters/{id}' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :id, in: :path, required: true,
              schema: { type: :string, pattern: '^\d{1,2}$' },
              description: 'Chapter short code (1–2 digits, e.g. "01")'

    get 'Retrieve a chapter' do
      tags 'Chapters'
      produces 'application/json'
      description 'Returns a single chapter including its headings, section, and guides.'
      operationId 'getChapter'

      response '200', 'chapter found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :object,
                   required: %w[id type attributes],
                   properties: {
                     id: { type: :string },
                     type: { type: :string, enum: %w[chapter] },
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
                         chapter_note: { type: :string, nullable: true },
                         forum_url: { type: :string, nullable: true },
                         section_id: { type: :integer, nullable: true },
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
                         guides: {
                           type: :object,
                           properties: {
                             data: {
                               type: :array,
                               items: {
                                 type: :object,
                                 properties: {
                                   id: { type: :string },
                                   type: { type: :string, enum: %w[guide] },
                                 },
                               },
                             },
                           },
                         },
                         headings: {
                           type: :object,
                           properties: {
                             data: {
                               type: :array,
                               items: {
                                 type: :object,
                                 properties: {
                                   id: { type: :string },
                                   type: { type: :string, enum: %w[heading] },
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
                   description: 'Related section, guide, and heading objects',
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

        let(:chapter) { create(:chapter, :with_section, :with_description) }
        let(:id) { chapter.goods_nomenclature_item_id.first(2) }

        run_test!
      end

      response '404', 'chapter not found' do
        let(:id) { '99' }

        run_test!
      end
    end
  end

  path '/api/chapters/{id}/changes' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :id, in: :path, required: true,
              schema: { type: :string, pattern: '^\d{1,2}$' },
              description: 'Chapter short code (1–2 digits, e.g. "01")'

    get 'List changes for a chapter' do
      tags 'Chapters'
      produces 'application/json'
      description 'Returns the changelog for a chapter.'
      operationId 'listChapterChanges'

      response '200', 'chapter changes listed' do
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

        let(:chapter) { create(:chapter, :with_description) }
        let(:id) { chapter.goods_nomenclature_item_id.first(2) }

        run_test!
      end
    end
  end
end
