module Api
  module Admin
    module Chapters
      class SectionSerializer
        include JSONAPI::Serializer

        set_type :section

        set_id :id

        attributes :id, :numeral, :title, :position
      end
    end
  end
end
