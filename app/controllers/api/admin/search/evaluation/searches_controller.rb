module Api
  module Admin
    module Search
      module Evaluation
        class SearchesController < AdminController
          def create
            EvaluationConfiguration::AllowlistValidator.call(configuration_overrides)

            result = Api::Internal::SearchService.new(search_params.to_h.merge(configuration_overrides:, search_type: 'evaluation')).call

            if result.is_a?(Hash) && result[:errors]
              render json: result, status: :unprocessable_content
            else
              render json: result
            end
          end

        private

          def configuration_overrides
            params.permit(configuration_overrides: {})[:configuration_overrides].to_h
          end

          def search_params
            params.permit(:q, :as_of, :request_id, :expanded_query, :skip_question, answers: %i[question answer options])
          end
        end
      end
    end
  end
end
