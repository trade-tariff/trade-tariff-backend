object @chapter

attributes :goods_nomenclature_sid, :goods_nomenclature_item_id, :description, :formatted_description

node(:chapter_note_id) { |chapter| chapter.chapter_note.try(:id) }
node(:section_id) { |chapter| chapter.section.id }

child :section do
  attributes :id, :title, :position, :numeral

  node(:section_note, if: ->(section) { section.section_note.present? }) do |section|
    section.section_note.content
  end
end

node(:chapter_note, if: ->(chapter) { chapter.chapter_note.present? }) do |chapter|
  chapter.chapter_note.content
end

child(:guides, if: ->(chapter) { chapter.guides.present? }) do
  attributes :title, :url
end

node(:headings) do
  @headings.map do |heading|
    partial('api/v1/headings/heading', object: heading)
  end
end

node(:_response_info) do
  {
    links: [
      { rel: 'self', href: request.fullpath },
      { rel: 'section', href: v1_api_path('sections', @chapter.section.position) },
    ],
  }
end
