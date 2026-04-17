require 'swagger_helper'

RSpec.describe 'News', swagger_doc: 'v2/swagger.json', type: :request do
  let(:Accept) { 'application/vnd.hmrc.2.0+json' }

  path '/api/news/items' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :page, in: :query, required: false,
              schema: { type: :integer },
              description: 'Page number'
    parameter name: :per_page, in: :query, required: false,
              schema: { type: :integer, enum: [1, 10, 20] },
              description: 'Results per page (1, 10, or 20; default 20)'
    parameter name: :collection_id, in: :query, required: false,
              schema: { type: :integer },
              description: 'Filter by collection ID'
    parameter name: :year, in: :query, required: false,
              schema: { type: :integer },
              description: 'Filter by publication year'

    get 'List news items' do
      tags 'News'
      produces 'application/json'
      description 'Returns paginated news items with collection relationships.'
      operationId 'listNewsItems'

      response '200', 'news items listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[news_item] },
                       attributes: {
                         type: :object,
                         properties: {
                           title: { type: :string, nullable: true },
                           precis: { type: :string, nullable: true },
                           content: { type: :string, nullable: true },
                           display_style: { type: :integer, nullable: true },
                           start_date: { type: :string, nullable: true, format: 'date' },
                           end_date: { type: :string, nullable: true, format: 'date' },
                           show_on_uk: { type: :boolean, nullable: true },
                           show_on_xi: { type: :boolean, nullable: true },
                         },
                       },
                     },
                   },
                 },
                 meta: {
                   type: :object,
                   properties: {
                     pagination: {
                       type: :object,
                       properties: {
                         page: { type: :integer },
                         per_page: { type: :integer },
                         total_count: { type: :integer },
                       },
                     },
                   },
                 },
               }

        before { create(:news_item) }

        run_test!
      end
    end
  end

  path '/api/news/items/{id}' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :id, in: :path, required: true,
              schema: { type: :string },
              description: 'News item ID or slug'

    get 'Retrieve a news item' do
      tags 'News'
      produces 'application/json'
      description 'Returns a single news item. Accepts either a numeric ID or a slug string.'
      operationId 'getNewsItem'

      response '200', 'news item found' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     id: { type: :string },
                     type: { type: :string, enum: %w[news_item] },
                     attributes: {
                       type: :object,
                       properties: {
                         title: { type: :string, nullable: true },
                         precis: { type: :string, nullable: true },
                         content: { type: :string, nullable: true },
                         display_style: { type: :integer, nullable: true },
                         start_date: { type: :string, nullable: true, format: 'date' },
                         end_date: { type: :string, nullable: true, format: 'date' },
                       },
                     },
                   },
                 },
               }

        let(:news_item) { create(:news_item) }
        let(:id) { news_item.id }

        run_test!
      end

      response '404', 'news item not found' do
        let(:id) { 999_999 }

        run_test!
      end
    end
  end

  path '/api/news/collections' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'

    get 'List news collections' do
      tags 'News'
      produces 'application/json'
      description 'Returns all published news collections.'
      operationId 'listNewsCollections'

      response '200', 'news collections listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[news_collection] },
                       attributes: {
                         type: :object,
                         properties: {
                           name: { type: :string, nullable: true },
                           description: { type: :string, nullable: true },
                           slug: { type: :string, nullable: true },
                         },
                       },
                     },
                   },
                 },
               }

        before { create(:news_collection) }

        run_test!
      end
    end
  end

  path '/api/news/years' do
    parameter name: :Accept, in: :header, required: true,
              schema: { type: :string, enum: ['application/vnd.hmrc.2.0+json'] },
              description: 'API version negotiation header'
    parameter name: :service, in: :query, required: false,
              schema: { type: :string, enum: %w[uk xi] },
              description: 'Tariff service to filter years by'

    get 'List news years' do
      tags 'News'
      produces 'application/json'
      description 'Returns distinct years for which updates-page news items exist in published collections.'
      operationId 'listNewsYears'

      response '200', 'news years listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, enum: %w[news_year] },
                       attributes: {
                         type: :object,
                         properties: {
                           year: { type: :integer, nullable: true },
                         },
                       },
                     },
                   },
                 },
               }

        before { create(:news_item, :updates_page) }

        run_test!
      end
    end
  end
end
