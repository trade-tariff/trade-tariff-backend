module Api
  module V2
    module Chapters
      class SectionSerializer
        include JSONAPI::Serializer

        set_type :section

        set_id :id

        attributes :id, :numeral, :title, :position
        attribute :section_note, if: proc { |section| section.customs_tariff_section_note.present? } do |section|
          section.customs_tariff_section_note.content
        end
      end
    end
  end
end
