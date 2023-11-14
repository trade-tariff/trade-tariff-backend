module Api
  module V2
    module Commodities
      class SectionSerializer
        include JSONAPI::Serializer

        set_type :section

        set_id :id

        attributes :numeral, :title, :position

        attribute :section_note, if: proc { |section| section.section_note.present? } do |section|
          section.section_note.content
        end
      end
    end
  end
end
