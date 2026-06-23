require 'swagger_helper'

RSpec.describe 'Classification Search', skip: 'Draft MCP API docs are held back until release', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/classification_search' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :q, in: :query, required: true,
              schema: { type: :string },
              description: 'Product description to search for classification candidates'
    parameter name: :limit, in: :query, required: false,
              schema: { type: :integer, minimum: 1, maximum: 50 },
              description: 'Maximum number of candidates to return'
    parameter name: :as_of, in: :query, required: false,
              schema: { type: :string, format: :date },
              description: 'Return data as it appeared on this date'
    parameter name: :expanded_query, in: :query, required: false,
              schema: { type: :string },
              description: 'Optional expanded query text to use for retrieval'

    get 'Get hybrid classification candidates' do
      tags 'Classification Search'
      produces 'application/json'
      description 'Returns a hybrid semantic shortlist of candidate goods nomenclatures for a product description.'
      operationId 'classificationSearch'

      response '200', 'classification candidates found' do
        schema type: :object,
               required: %w[data meta],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[classification_search_result] },
                       attributes: {
                         type: :object,
                         properties: {
                           goods_nomenclature_item_id: { type: :string, nullable: true },
                           goods_nomenclature_sid: { type: :integer, nullable: true },
                           producline_suffix: { type: :string, nullable: true },
                           goods_nomenclature_class: { type: :string, nullable: true },
                           description: { type: :string, nullable: true },
                           formatted_description: { type: :string, nullable: true },
                           self_text: { type: :string, nullable: true },
                           classification_description: { type: :string, nullable: true },
                           full_description: { type: :string, nullable: true },
                           heading_description: { type: :string, nullable: true },
                           declarable: { type: :boolean, nullable: true },
                           score: { type: :number, nullable: true },
                           confidence: { type: :number, nullable: true },
                         },
                       },
                     },
                   },
                 },
                 meta: {
                   type: :object,
                   properties: {
                     request_id: { type: :string },
                     retrieval_method: { type: :string, enum: %w[hybrid] },
                     expanded_query: { type: :string, nullable: true },
                     result_count: { type: :integer },
                     max_score: { type: :number, nullable: true },
                   },
                 },
               }

        let(:q) { 'wireless headphones' }
        let(:limit) { 5 }

        before do
          allow(Api::V2::ClassificationSearchService).to receive(:new).and_return(
            instance_double(Api::V2::ClassificationSearchService, call: { data: [], meta: { request_id: 'test', retrieval_method: 'hybrid', expanded_query: 'wireless headphones', result_count: 0, max_score: nil } }),
          )
        end

        run_test!
      end
    end

    post 'Post hybrid classification candidates' do
      tags 'Classification Search'
      consumes 'application/json'
      produces 'application/json'
      description 'Returns a hybrid semantic shortlist of candidate goods nomenclatures for a product description.'
      operationId 'postClassificationSearch'

      parameter name: :body, in: :body, required: true,
                schema: {
                  type: :object,
                  required: %w[q],
                  properties: {
                    q: { type: :string },
                    limit: { type: :integer, minimum: 1, maximum: 50 },
                    as_of: { type: :string, format: :date },
                    expanded_query: { type: :string },
                  },
                }

      response '200', 'classification candidates found' do
        schema type: :object,
               required: %w[data meta],
               properties: {
                 data: { type: :array },
                 meta: { type: :object },
               }

        let(:body) { { q: 'wireless headphones', limit: 5 } }
        let(:q) { nil }
        let(:limit) { nil }
        let(:as_of) { nil }
        let(:expanded_query) { nil }

        before do
          allow(Api::V2::ClassificationSearchService).to receive(:new).and_return(
            instance_double(Api::V2::ClassificationSearchService, call: { data: [], meta: { request_id: 'test', retrieval_method: 'hybrid', expanded_query: 'wireless headphones', result_count: 0, max_score: nil } }),
          )
        end

        run_test!
      end
    end
  end
end
