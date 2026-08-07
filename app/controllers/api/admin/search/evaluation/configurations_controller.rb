module Api
  module Admin
    module Search
      module Evaluation
        class ConfigurationsController < AdminController
          def show
            # Reference AllowlistValidator to trigger Zeitwerk autoloading, making ALLOWED_OVERRIDE_KEYS available
            _ = EvaluationConfiguration::AllowlistValidator

            render json: {
              baseline: EvaluationConfiguration::BaselineProvider.call,
              allowed_overrides: EvaluationConfiguration::ALLOWED_OVERRIDE_KEYS,
            }
          end
        end
      end
    end
  end
end
