module Api
  module V2
    module KnowledgeGraph
      class QueriesController < ApiController
        no_caching

        def create
          result = ::TariffKnowledge::GraphQuery.call(attributes)

          if result[:errors]
            render json: { errors: jsonapi_errors(result[:errors]) }, status: :unprocessable_content
          else
            render json: result
          end
        end

        private

        def attributes
          params.fetch(:data, {}).fetch(:attributes, {}).to_unsafe_h
        end

        def jsonapi_errors(errors)
          errors.map do |error|
            {
              status: '422',
              title: 'Invalid knowledge graph query',
              detail: error[:detail],
              source: {
                pointer: error[:pointer],
              },
            }
          end
        end
      end
    end
  end
end
