module Api
  module Admin
    module Search
      module Evaluation
        class ConfigurationsController < AdminController
          def show
            render json: {
              baseline: EvaluationConfiguration::BaselineProvider.call,
              allowed_overrides: EvaluationConfiguration::OverrideSchema.call,
            }
          end
        end
      end
    end
  end
end
