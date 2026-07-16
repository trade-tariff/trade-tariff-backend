require 'swagger_helper'

RSpec.describe 'Sections V3', swagger_doc: 'v3/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.3.0+json' }

  path '/api/v3/sections' do
    get 'List all sections' do
      tags 'Sections'
      description 'Returns all tariff sections. Sections group chapters into broad categories of goods.'
      operationId 'listSectionsV3'

      response '200', 'sections listed' do
        schema type: :object,
               required: %w[data meta],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     required: %w[id numeral title position],
                     properties: {
                       id: { type: :integer },
                       numeral: { type: :string, example: 'I' },
                       title: { type: :string },
                       position: { type: :integer },
                       chapter_from: { type: :string, nullable: true },
                       chapter_to: { type: :string, nullable: true },
                       section_note: { type: :string, nullable: true },
                     },
                   },
                 },
                 meta: { '$ref' => '#/components/schemas/meta' },
               }

        before { create(:section, position: 1, numeral: 'I', title: 'Live Animals') }

        run_test!
      end
    end
  end

  path '/api/v3/sections/{id}' do
    parameter name: :id, in: :path, schema: { type: :integer }, required: true,
              description: 'Section position number'

    get 'Retrieve a section' do
      tags 'Sections'
      operationId 'getSectionV3'

      response '200', 'section found' do
        schema type: :object,
               required: %w[id numeral title position],
               properties: {
                 id: { type: :integer },
                 numeral: { type: :string },
                 title: { type: :string },
                 position: { type: :integer },
                 chapter_from: { type: :string, nullable: true },
                 chapter_to: { type: :string, nullable: true },
                 section_note: { type: :string, nullable: true },
               }

        let(:id) { create(:section, position: 1, numeral: 'I', title: 'Live Animals').position }

        run_test!
      end

      response '404', 'section not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { 9999 }
        run_test!
      end
    end
  end

  path '/api/v3/sections/{id}/chapters' do
    parameter name: :id, in: :path, schema: { type: :integer }, required: true,
              description: 'Section position number'

    get 'List chapters in a section' do
      tags 'Sections'
      operationId 'listSectionChaptersV3'

      response '200', 'chapters listed' do
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

        let(:id) { create(:section, :with_chapter, position: 1).position }

        run_test!
      end
    end
  end
end
