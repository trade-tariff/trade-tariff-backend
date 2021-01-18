attributes :goods_nomenclature_sid, :goods_nomenclature_item_id,
           :declarable, :description, :producline_suffix, :leaf,
           :description_plain, :formatted_description

node(:search_references_count) { |heading| heading.search_references.count }

node(:children) { |heading|
  heading.children.map do |heading|
    partial('api/v1/headings/heading', object: heading)
  end
}
