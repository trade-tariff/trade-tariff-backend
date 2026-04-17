require 'swagger_helper'

RSpec.describe 'Sections', swagger_doc: 'v2/swagger.json', type: :request do
  # Provides Accept header for all requests in this file.
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/sections' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'

    get 'List all sections' do
      tags 'Sections'
      produces 'application/json'
      description 'Returns all sections of the tariff. Sections group chapters into broad categories of goods.'
      operationId 'listSections'

      response '200', 'sections listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     required: %w[id type attributes],
                     properties: {
                       id: { type: :string, description: 'Section ID' },
                       type: { type: :string, enum: %w[section] },
                       attributes: {
                         type: :object,
                         required: %w[id numeral title position],
                         properties: {
                           id: { type: :integer },
                           numeral: { type: :string, description: 'Roman numeral (e.g. I, II, XIV)' },
                           title: { type: :string },
                           position: { type: :integer, description: 'Ordering position' },
                           chapter_from: { type: :string, nullable: true, description: 'First chapter number in this section' },
                           chapter_to: { type: :string, nullable: true, description: 'Last chapter number in this section' },
                         },
                       },
                     },
                   },
                 },
               }

        before { create(:section, id: 1, position: 1, numeral: 'I', title: 'Live Animals; Animal Products') }

        run_test!
      end
    end
  end

  path '/api/sections/{id}' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :id, in: :path, required: true,
              schema: { type: :integer },
              description: 'Section position number'

    get 'Retrieve a section' do
      tags 'Sections'
      produces 'application/json'
      description 'Returns a single section including its chapters and any associated guides.'
      operationId 'getSection'

      response '200', 'section found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :object,
                   required: %w[id type attributes],
                   properties: {
                     id: { type: :string },
                     type: { type: :string, enum: %w[section] },
                     attributes: {
                       type: :object,
                       required: %w[id numeral title position],
                       properties: {
                         id: { type: :integer },
                         numeral: { type: :string },
                         title: { type: :string },
                         position: { type: :integer },
                         chapter_from: { type: :string, nullable: true },
                         chapter_to: { type: :string, nullable: true },
                         description_plain: { type: :string, nullable: true },
                         section_note: { type: :string, nullable: true, description: 'Legal note text, present when a note exists' },
                       },
                     },
                     relationships: {
                       type: :object,
                       properties: {
                         chapters: {
                           type: :object,
                           properties: {
                             data: {
                               type: :array,
                               items: {
                                 type: :object,
                                 properties: {
                                   id: { type: :string },
                                   type: { type: :string, enum: %w[chapter] },
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
                   description: 'Related chapter objects',
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[chapter] },
                       attributes: {
                         type: :object,
                         properties: {
                           goods_nomenclature_sid: { type: :integer },
                           goods_nomenclature_item_id: { type: :string },
                           headings_from: { type: :string, nullable: true },
                           headings_to: { type: :string, nullable: true },
                           description: { type: :string, nullable: true },
                           formatted_description: { type: :string, nullable: true },
                           validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                           validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                         },
                       },
                     },
                   },
                 },
               }

        let(:section) { create(:section, :with_chapter) }
        let(:id) { section.position }

        run_test!
      end

      response '400', 'invalid section id — id must be an integer' do
        # The controller returns head :bad_request (empty body) for non-integer ids.
        let(:id) { 'invalid' }

        run_test!
      end
    end
  end

  path '/api/sections/{id}/chapters' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :id, in: :path, required: true,
              schema: { type: :integer },
              description: 'Section position number'

    get 'List chapters in a section' do
      tags 'Sections'
      produces 'application/json'
      description 'Returns all chapters belonging to a section.'
      operationId 'listSectionChapters'

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
                           headings_from: { type: :string, nullable: true },
                           headings_to: { type: :string, nullable: true },
                           description: { type: :string, nullable: true },
                           formatted_description: { type: :string, nullable: true },
                           validity_start_date: { type: :string, nullable: true, format: 'date-time' },
                           validity_end_date: { type: :string, nullable: true, format: 'date-time' },
                         },
                       },
                     },
                   },
                 },
               }

        let(:section) { create(:section, :with_chapter) }
        let(:id) { section.position }

        run_test!
      end
    end
  end
end
