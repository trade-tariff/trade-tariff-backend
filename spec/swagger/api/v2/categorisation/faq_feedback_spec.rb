require 'swagger_helper'

RSpec.describe 'Categorisation FAQ Feedback', swagger_doc: 'v2/swagger.json', type: :request do
  let(:accept) { 'application/vnd.hmrc.2.0+json' }

  before { allow(TradeTariffBackend).to receive(:uk?).and_return(false) }

  faq_feedback_schema = {
    type: :object,
    required: %w[id type attributes],
    properties: {
      id: { type: :string },
      type: { type: :string, enum: %w[green_lanes_faq_feedback] },
      attributes: {
        type: :object,
        properties: {
          session_id: { type: :string },
          category_id: { type: :integer },
          question_id: { type: :integer },
          useful: { type: :boolean },
        },
      },
    },
  }.freeze

  faq_feedback_request_schema = {
    type: :object,
    required: %w[data],
    properties: {
      data: {
        type: :object,
        required: %w[type attributes],
        properties: {
          type: { type: :string, enum: %w[green_lanes_faq_feedback] },
          attributes: {
            type: :object,
            required: %w[session_id category_id question_id useful],
            properties: {
              session_id: { type: :string, description: 'Opaque session identifier supplied by the client.' },
              category_id: { type: :integer, description: 'FAQ category being rated.' },
              question_id: { type: :integer, description: 'FAQ question being rated.' },
              useful: { type: :boolean, description: 'Whether the FAQ answer was useful.' },
            },
          },
        },
      },
    },
  }.freeze

  path '/api/categorisation/faq_feedback' do
    parameter '$ref' => '#/components/parameters/accept_header'

    get 'List Categorisation FAQ feedback' do
      tags 'Categorisation'
      security [{ oauth2_client_credentials: ['tariff/categorisation'] }]
      produces 'application/json'
      description 'Returns all submitted Categorisation (Green Lanes) FAQ feedback records. ' \
                   'Available on the Northern Ireland (XI) service only.'
      operationId 'getCategorisationFaqFeedback'

      response '200', 'FAQ feedback listed' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: {
                   type: :array,
                   items: faq_feedback_schema,
                 },
               }

        before { create(:green_lanes_faq_feedback) }

        run_test!
      end
    end

    post 'Submit Categorisation FAQ feedback' do
      tags 'Categorisation'
      security [{ oauth2_client_credentials: ['tariff/categorisation'] }]
      consumes 'application/json'
      produces 'application/json'
      description 'Records whether a Categorisation (Green Lanes) FAQ answer was useful. ' \
                   'Available on the Northern Ireland (XI) service only.'
      operationId 'postCategorisationFaqFeedback'

      parameter name: :faq_feedback, in: :body, required: true,
                schema: faq_feedback_request_schema,
                description: 'JSON:API request body containing the feedback to record.'

      response '201', 'FAQ feedback recorded' do
        schema type: :object,
               required: %w[data],
               properties: {
                 data: faq_feedback_schema,
               }

        let(:faq_feedback) do
          {
            data: {
              type: 'green_lanes_faq_feedback',
              attributes: attributes_for(:green_lanes_faq_feedback),
            },
          }
        end

        run_test!
      end

      response '422', 'FAQ feedback invalid' do
        schema type: :object,
               required: %w[errors],
               properties: {
                 errors: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       title: { type: :string, description: 'Invalid attribute name.' },
                       detail: { type: :array, items: { type: :string }, description: 'Validation messages for the attribute.' },
                     },
                   },
                 },
               }

        let(:faq_feedback) do
          {
            data: {
              type: 'green_lanes_faq_feedback',
              attributes: attributes_for(:green_lanes_faq_feedback, session_id: nil),
            },
          }
        end

        run_test!
      end
    end
  end
end
