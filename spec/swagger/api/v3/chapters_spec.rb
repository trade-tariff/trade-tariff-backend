require 'swagger_helper'

RSpec.describe 'Chapters V3', swagger_doc: 'v3/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.3.0+json' }

  path '/api/v3/chapters/{id}' do
    parameter name: :id, in: :path, schema: { type: :string, example: '01' }, required: true,
              description: 'Two-digit chapter number (e.g. 01, 99)'

    get 'Retrieve a chapter' do
      tags 'Chapters'
      produces 'application/json'
      operationId 'getChapterV3'

      response '200', 'chapter found' do
        schema type: :object,
               required: %w[goods_nomenclature_sid goods_nomenclature_item_id],
               properties: {
                 goods_nomenclature_sid: { type: :integer },
                 goods_nomenclature_item_id: { type: :string, example: '0100000000' },
                 description: { type: :string, nullable: true },
                 formatted_description: { type: :string, nullable: true },
                 validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                 validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                 chapter_note: { type: :string, nullable: true },
                 section_id: { type: :integer, nullable: true },
               }

        let(:id) { create(:chapter, :with_section, goods_nomenclature_item_id: '0100000000').goods_nomenclature_item_id.first(2) }

        run_test!
      end

      response '404', 'chapter not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { '99' }
        run_test!
      end
    end
  end

  path '/api/v3/chapters/{id}/headings' do
    parameter name: :id, in: :path, schema: { type: :string, example: '01' }, required: true,
              description: 'Two-digit chapter number'

    get 'List headings in a chapter' do
      tags 'Chapters'
      produces 'application/json'
      operationId 'listChapterHeadingsV3'

      response '200', 'headings listed' do
        schema type: :object,
               required: %w[data meta],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       goods_nomenclature_sid: { type: :integer },
                       goods_nomenclature_item_id: { type: :string },
                       description: { type: :string, nullable: true },
                       formatted_description: { type: :string, nullable: true },
                       validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                       validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                     },
                   },
                 },
                 meta: { '$ref' => '#/components/schemas/meta' },
               }

        let(:id) { create(:chapter, :with_section, :with_headings, goods_nomenclature_item_id: '0100000000').goods_nomenclature_item_id.first(2) }

        run_test!
      end
    end
  end
end
