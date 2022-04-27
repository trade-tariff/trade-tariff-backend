class Section < Sequel::Model
  extend ActiveModel::Naming

  plugin :timestamps
  plugin :active_model
  plugin :nullable
  plugin :elasticsearch

  many_to_many :chapters, dataset: -> {
    Chapter.join_table(:inner, :chapters_sections, chapters_sections__goods_nomenclature_sid: :goods_nomenclatures__goods_nomenclature_sid)
           .join_table(:inner, :sections, chapters_sections__section_id: :sections__id)
           .with_actual(Chapter)
           .where(Sequel.~(goods_nomenclatures__goods_nomenclature_item_id: HiddenGoodsNomenclature.codes))
           .where(sections__id: id)
  }, eager_loader: (proc do |eo|
    eo[:rows].each { |section| section.associations[:chapters] = [] }

    id_map = eo[:id_map]

    Chapter.join_table(:inner, :chapters_sections, chapters_sections__goods_nomenclature_sid: :goods_nomenclatures__goods_nomenclature_sid)
           .join_table(:inner, :sections, chapters_sections__section_id: :sections__id)
           .with_actual(Chapter)
           .where(Sequel.~(goods_nomenclatures__goods_nomenclature_item_id: HiddenGoodsNomenclature.codes))
           .where(sections__id: id_map.keys).all do |chapter|
      if sections = id_map[chapter[:section_id]]
        sections.each do |section|
          section.associations[:chapters] << chapter
        end
      end
    end
  end)

  def chapter_ids
    chapters.pluck(:goods_nomenclature_sid)
  end

  one_to_one :section_note

  one_to_many :search_references, key: Sequel.cast_numeric(:referenced_id), key_method: :referenced_id_number,
                                  reciprocal: :referenced, conditions: { referenced_class: 'Section' },
                                  adder: proc { |search_reference| search_reference.update(referenced_id: id, referenced_class: 'Section') },
                                  remover: proc { |search_reference| search_reference.update(referenced_id: nil, referenced_class: nil) },
                                  clearer: proc { search_references_dataset.update(referenced_id: nil, referenced_class: nil) }

  def first_chapter
    chapters.first || NullObject.new
  end

  def last_chapter
    chapters.last || NullObject.new
  end

  def chapter_from
    first_chapter.short_code
  end

  def chapter_to
    last_chapter.short_code
  end
end
