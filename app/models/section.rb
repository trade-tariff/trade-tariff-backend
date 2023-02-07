class Section < Sequel::Model
  extend ActiveModel::Naming

  set_dataset order(Sequel.asc(:position))

  plugin :timestamps
  plugin :active_model
  plugin :nullable
  plugin :elasticsearch

  many_to_many :chapters, dataset: lambda {
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
      sections = id_map[chapter[:section_id]]

      if sections.present?
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
