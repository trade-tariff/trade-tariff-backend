class Section < Sequel::Model
  extend ActiveModel::Naming
  include Formatter

  set_dataset order(Sequel.asc(:position))

  plugin :timestamps

  many_to_many :chapters,
               join_table: :chapters_sections,
               left_key: :section_id,
               right_key: :goods_nomenclature_sid,
               right_primary_key: :goods_nomenclature_sid,
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

  one_to_one :current_customs_tariff_section_note, class: :CustomsTariffSectionNote, key: :section_id, primary_key: :id do |ds|
    ds.where(
      customs_tariff_update_version: CustomsTariffUpdate.actual
        .exclude(status: CustomsTariffUpdate::FAILED)
        .order(Sequel.desc(:validity_start_date))
        .select(:version)
        .limit(1),
    )
  end
  one_to_one :customs_tariff_section_note, key: :section_id, primary_key: :id do |ds|
    ds.where(
      customs_tariff_update_version: CustomsTariffUpdate.actual
        .exclude(status: CustomsTariffUpdate::FAILED)
        .order(Sequel.desc(:validity_start_date))
        .select(:version)
        .limit(1),
    )
  end

  def public_section_note
    if TradeTariffBackend.promote_customs_tariff_notes?
      customs_tariff_section_note
    else
      section_note
    end
  end

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
