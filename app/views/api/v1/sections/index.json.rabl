collection @sections
attributes :id, :position, :title, :numeral, :chapter_from, :chapter_to
node(:section_note_id) { |section| section.section_note.try(:id) }
node(:search_references_count) { |_section| 0 }
