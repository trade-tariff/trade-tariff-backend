class Chapter < GoodsNomenclature
  plugin :oplog, primary_key: :goods_nomenclature_sid, materialized: true
  plugin :elasticsearch

  set_dataset filter('goods_nomenclatures.goods_nomenclature_item_id LIKE ?', '__00000000')
              .order(
                Sequel.asc(:goods_nomenclature_item_id),
                Sequel.asc(:goods_nomenclatures__producline_suffix),
              )

  set_primary_key [:goods_nomenclature_sid]

  many_to_many :sections, left_key: :goods_nomenclature_sid,
                          join_table: :chapters_sections

  include SearchReferenceable

  one_to_many :headings, primary_key: :chapter_short_code, key: :chapter_short_code, foreign_key: :chapter_short_code do |ds|
    ds.with_actual(Heading).non_hidden
  end

  one_to_one :chapter_note, primary_key: :chapter_short_code

  def guide_ids
    guides.pluck(:id)
  end

  def section_id
    section&.id
  end

  def heading_ids
    headings.pluck(:goods_nomenclature_sid)
  end

  dataset_module do
    def by_code(code = '')
      filter(goods_nomenclatures__goods_nomenclature_item_id: "#{code.to_s.first(2)}00000000")
    end
  end

  # See oplog sequel plugin
  def operation=(operation)
    self[:operation] = operation.to_s.first.upcase
  end

  def short_code
    goods_nomenclature_item_id.first(2)
  end

  # Override to avoid lookup, this is default behaviour for chapters.
  def number_indents
    0
  end

  def to_param
    short_code
  end

  def section
    sections.first
  end

  def first_heading
    headings.min_by(&:goods_nomenclature_item_id) || NullObject.new
  end

  def last_heading
    headings.max_by(&:goods_nomenclature_item_id) || NullObject.new
  end

  def headings_from
    first_heading.short_code
  end

  def headings_to
    last_heading.short_code
  end

  def changes(depth = 1)
    operation_klass.select(
      Sequel.as(Sequel.cast_string('Chapter'), :model),
      :oid,
      :operation_date,
      :operation,
      Sequel.as(depth, :depth),
    ).where(pk_hash)
     .union(Heading.changes_for(depth + 1, ['goods_nomenclature_item_id LIKE ? AND goods_nomenclature_item_id NOT LIKE ?', relevant_headings, '__00______']))
     .union(Commodity.changes_for(depth + 1, ['goods_nomenclature_item_id LIKE ? AND goods_nomenclature_item_id NOT LIKE ?', relevant_goods_nomenclature, '____000000'])).union(Measure.changes_for(depth + 1, ['goods_nomenclature_item_id LIKE ?', relevant_goods_nomenclature]))
     .from_self
     .where(Sequel.~(operation_date: nil))
     .tap! { |criteria|
      # if Chapter did not come from initial seed, filter by its
      # create/update date
      criteria.where { |o| o.>=(:operation_date, operation_date) } if operation_date.present?
    }
     .limit(TradeTariffBackend.change_count)
     .order(Sequel.desc(:operation_date, nulls: :last), Sequel.desc(:depth))
  end

  private

  def relevant_headings
    "#{short_code}__000000"
  end

  def relevant_goods_nomenclature
    "#{short_code}________"
  end
end
