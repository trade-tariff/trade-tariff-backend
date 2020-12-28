module Api
  module V2
    module Measures
      class MeasureLegalActSerializer
        include JSONAPI::Serializer

        set_type :legal_act

        set_id :regulation_id

        attributes :validity_start_date, :validity_end_date, :officialjournal_number,
                   :officialjournal_page

        attribute :published_date do |regulation|
          regulation.try(:published_date)
        end
        
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
