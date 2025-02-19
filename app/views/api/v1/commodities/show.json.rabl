object @commodity
cache @commodity_cache_key, expires_at: actual_date.end_of_day

attributes :producline_suffix, :description, :number_indents,
           :goods_nomenclature_item_id, :bti_url, :formatted_description,
           :description_plain, :consigned, :consigned_from, :basic_duty_rate

footnotes = (@commodity.footnotes + @commodity.heading.footnotes).uniq
if footnotes.any?
  child(footnotes) do
    attributes :code, :description, :formatted_description
  end
end

extends 'api/v1/declarables/declarable', object: @commodity, locals: { measures: @measures }

child @commodity.heading do
  attributes :goods_nomenclature_item_id, :description, :formatted_description,
             :description_plain
end

child @commodity.chapter do |chapter|
  attributes :goods_nomenclature_item_id, :description, :formatted_description
  if chapter.chapter_note.present?
    node :chapter_note do
      chapter.chapter_note.content
    end
  end

  child chapter.guides do
    attributes :title, :url
  end
end

child(@commodity.ancestors => :ancestors) do
  attributes :producline_suffix,
             :description,
             :number_indents,
             :goods_nomenclature_item_id,
             :leaf,
             :uk_vat_rate,
             :formatted_description,
             :description_plain
end

node(:_response_info) do
  {
    links: [
      { rel: 'self', href: request.fullpath },
      { rel: 'heading', href: api_heading_path(@commodity.heading) },
      { rel: 'chapter', href: api_chapter_path(@commodity.chapter) },
      { rel: 'section', href: api_section_path(@commodity.section.position) },
    ],
  }
end
