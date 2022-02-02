module Api
  module V2
    module Subheadings
      class SectionSerializer
        include JSONAPI::Serializer

        set_type :section

        set_id :id

        attributes :numeral, :title, :position, :section_note
      end
    end
  end
end
