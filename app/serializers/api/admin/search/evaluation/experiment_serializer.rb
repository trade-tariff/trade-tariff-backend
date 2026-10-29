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
                     :gold_query_set_id,
                     :synthetic_input_set_id,
                     :created_at,
                     :created_by

          # Which kind of set the experiment uses and its name, so the admin app can show it
          # (linked, using the id above) without asking for the set separately.
          attribute :source_type, &:source_type
          attribute :source_name, &:source_name
        end
      end
    end
  end
end
