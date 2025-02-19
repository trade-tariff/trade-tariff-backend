object @heading
cache @heading_cache_key, expires_at: actual_date.end_of_day

attributes :goods_nomenclature_item_id, :description, :bti_url,
           :formatted_description

footnotes = @heading.footnotes
if footnotes.any?
  child(footnotes) do
    attributes :code, :description, :formatted_description
  end
end

if @heading.declarable?
  attributes :basic_duty_rate

  extends 'api/v1/declarables/declarable', object: @heading, locals: { measures: @heading.applicable_measures }
else
  child :chapter do
    attributes :goods_nomenclature_item_id, :description, :formatted_description
    node(:chapter_note, if: ->(chapter) { chapter.chapter_note.present? }) do |chapter|
      chapter.chapter_note.content
    end
    child(:guides, if: ->(chapter) { chapter.guides.present? }) do
      attributes :title, :url
    end
  end

  child :section do
    attributes :title, :numeral, :position
    node(:section_note, if: ->(section) { section.section_note.present? }) do |section|
      section.section_note.content
    end
  end

  child(@heading.descendants) do
    attributes :description,
               :number_indents,
               :goods_nomenclature_item_id,
               :goods_nomenclature_sid,
               :formatted_description,
               :description_plain,
               :producline_suffix

    attribute :leaf?, &:leaf

    node(:parent_sid) { |commodity| commodity.parent.try(:goods_nomenclature_sid) }
    node(:search_references_count) { |commodity| commodity.search_references.count }
  end
end

node(:_response_info) do
  {
    links: [
      { rel: 'self', href: request.fullpath },
      { rel: 'chapter', href: v1_api_path('chapters', @heading.chapter_short_code) },
      { rel: 'section', href: v1_api_path('sections', @heading.section.position) },
    ],
  }
end
