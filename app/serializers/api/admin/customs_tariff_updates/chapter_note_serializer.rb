module Api
  module Admin
    module CustomsTariffUpdates
      class ChapterNoteSerializer
        include JSONAPI::Serializer

        set_type :customs_tariff_chapter_note
        set_id   :chapter_id

        attributes :chapter_id, :content, :customs_tariff_update_version

        attribute :file_diff do |note, params|
          params[:file_diff] || params[:file_diffs]&.dig(note.chapter_id)
        end

        attribute :versions do |_note, params|
          (params[:versions] || []).map do |v|
            {
              id: v.id,
              item_type: v.item_type,
              item_id: v.item_id,
              event: v.event,
              object: v.object,
              whodunnit: v.whodunnit,
              created_at: v.created_at,
              changeset: v.changeset,
            }
          end
        end
      end
    end
  end
end
