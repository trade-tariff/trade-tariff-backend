module Api
  module V2
    module Measures
      class MeasureSuspensionLegalActSerializer
        include JSONAPI::Serializer

        set_type :suspension_legal_act

        set_id :regulation_id

        attribute :validity_end_date, &:effective_end_date

        attribute :validity_start_date, &:effective_start_date

        attribute :regulation_code do |regulation|
          ApplicationHelper.regulation_code(regulation)
        end

        attribute :regulation_url do |regulation|
          ApplicationHelper.regulation_url(regulation)
        end
      end
    end
  end
end
