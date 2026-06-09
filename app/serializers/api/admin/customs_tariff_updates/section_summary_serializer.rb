module Api
  module Admin
    module CustomsTariffUpdates
      class SectionSummarySerializer
        include JSONAPI::Serializer

        set_type :section_summary
        set_id   :section_id

        attributes :section_id, :section_title, :position,
                   :section_note_id, :section_note_status,
                   :chapter_notes_total, :chapter_notes_changed
      end
    end
  end
end
