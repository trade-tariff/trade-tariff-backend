module Api
  module V2
    module Measures
      class MeasureLegalActSerializer
        include JSONAPI::Serializer

        set_type :legal_act

        set_id :regulation_id

        attributes :validity_start_date, :validity_end_date, :officialjournal_number,
                   :officialjournal_page, :published_date, :regulation_code,
                   :regulation_url, :description
      end
    end
  end
end
