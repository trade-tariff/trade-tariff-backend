module Api
  module Admin
    module Search
      module Evaluation
        class ExperimentSerializer
          include JSONAPI::Serializer

          set_type :experiment
          set_id :id

          attributes :name,
                     :description,
                     :enabled,
                     :configuration_overrides,
                     :default_scope,
                     :created_at,
                     :created_by
        end
      end
    end
  end
end
