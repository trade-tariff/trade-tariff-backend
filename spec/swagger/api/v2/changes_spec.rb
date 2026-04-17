require 'swagger_helper'

RSpec.describe 'Changes', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  change_item_schema = {
    type: :object,
    properties: {
      id: { type: :string },
      type: { type: :string, enum: %w[change] },
      attributes: {
        type: :object,
        properties: {
          goods_nomenclature_sid: { type: :integer, nullable: true },
          goods_nomenclature_item_id: { type: :string, nullable: true },
          productline_suffix: { type: :string, nullable: true },
          end_line: { type: :boolean, nullable: true },
          change_type: { type: :string, nullable: true },
          change_date: { type: :string, nullable: true, format: 'date' },
        },
      },
    },
  }.freeze

  path '/api/changes' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'

    get 'List recent tariff changes' do
      tags 'Changes'
      produces 'application/json'
      description 'Returns recent tariff changes. The data array may be empty if no changes exist for the current date.'
      operationId 'listChanges'

      response '200', 'changes listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: change_item_schema,
                 },
               }

        before { create(:change) }

        run_test!
      end
    end
  end

  path '/api/changes/{as_of}' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :as_of, in: :path, required: true,
              schema: { type: :string, pattern: '^\d{4}-\d{1,2}-\d{1,2}$' },
              description: 'Date to filter changes by (format: YYYY-M-D, e.g. "2024-1-15")'

    get 'List tariff changes for a date' do
      tags 'Changes'
      produces 'application/json'
      description 'Returns tariff changes for the specified date. The data array may be empty if no changes exist for that date.'
      operationId 'listChangesAsOf'

      response '200', 'changes listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: change_item_schema,
                 },
               }

        let(:as_of) { Date.current.strftime('%Y-%-m-%-d') }

        before { create(:change, change_date: Date.current) }

        run_test!
      end
    end
  end
end
