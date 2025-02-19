object @section

attributes :id, :position, :title, :numeral, :chapter_from, :chapter_to

node(:section_note, if: ->(section) { section.section_note.present? }) do |section|
  section.section_note.content
end

child(chapters: :chapters) do
  attributes :description, :goods_nomenclature_item_id, :goods_nomenclature_sid,
             :headings_from, :headings_to, :formatted_description

  child(:guides, if: ->(chapter) { chapter.guides.present? }) do
    attributes :title, :url
  end

  node(:chapter_note_id) { |chapter| chapter.chapter_note.try(:id) }
  node(:search_references_count) { |chapter| chapter.search_references_dataset.count }
end

node(:_response_info) do
  {
    links: [
      { rel: 'self', href: request.fullpath },
      { rel: 'sections', href: api_sections_path },
    ],
  }
end
