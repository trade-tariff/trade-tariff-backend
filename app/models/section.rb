class Section < Sequel::Model
  extend ActiveModel::Naming
  include Formatter

  set_dataset order(Sequel.asc(:position))

  plugin :timestamps
  plugin :active_model
  plugin :nullable
  plugin :elasticsearch

  many_to_many :chapters,
               join_table: :chapters_sections,
               left_key: :section_id,
               right_key: :goods_nomenclature_sid,
               right_primary_key: :goods_nomenclature_sid,
               use_optimized: false,
               graph_use_association_block: true do |ds|
    ds.with_actual(Chapter)
      .where(Sequel.~(goods_nomenclatures__goods_nomenclature_item_id: HiddenGoodsNomenclature.codes))
  end

  custom_format :description_plain, with: DescriptionTrimFormatter,
                                    using: :title

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
