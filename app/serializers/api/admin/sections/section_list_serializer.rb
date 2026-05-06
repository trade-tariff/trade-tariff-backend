module Api
  module Admin
    module Sections
      class SectionListSerializer
        include JSONAPI::Serializer

        set_type :section

        set_id :id

        attributes :id, :numeral, :title, :position, :chapter_from, :chapter_to

        attribute :section_note_id do |section|
          note = TradeTariffBackend.uk? ? section.customs_tariff_section_note : section.section_note
          note&.id
        end
      end
    end
  end
end
