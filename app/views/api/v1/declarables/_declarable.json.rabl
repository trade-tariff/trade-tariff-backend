node(:declarable) { true }

attributes :meursing_code

child :section do
  attributes :title, :position, :numeral

  node(:section_note, if: lambda { |section| section.section_note.present? }) do |section|
    section.section_note.content
  end
end

child :chapter do
  attributes :goods_nomenclature_item_id, :description, :formatted_description

  node(:chapter_note, if: lambda { |chapter| chapter.chapter_note.present? }) do |chapter|
    chapter.chapter_note.content
  end

  child(:guides, if: lambda { |chapter| chapter.guides.present? }) do
    attributes :title, :url
  end
end

node(:import_measures) { |declarable|
  locals[:measures].select(&:import).map do |import_measure|
    partial 'api/v1/measures/measure', object: import_measure, locals: { declarable: declarable }
  end
}

node(:export_measures) { |declarable|
  locals[:measures].select(&:export).map do |export_measure|
    partial 'api/v1/measures/_measure', object: export_measure, locals: { declarable: declarable }
  end
}
