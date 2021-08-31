class Chapter < GoodsNomenclature
  plugin :oplog, primary_key: :goods_nomenclature_sid
  plugin :elasticsearch

  set_dataset filter('goods_nomenclatures.goods_nomenclature_item_id LIKE ?', '__00000000')
              .order(Sequel.asc(:goods_nomenclature_item_id))

  set_primary_key [:goods_nomenclature_sid]

  many_to_many :sections, left_key: :goods_nomenclature_sid,
                          join_table: :chapters_sections

  one_to_many :headings, dataset: -> {
    Heading.actual
           .filter("goods_nomenclature_item_id LIKE ? AND goods_nomenclature_item_id NOT LIKE '__00______'", relevant_headings)
           .where(Sequel.~(goods_nomenclatures__goods_nomenclature_item_id: HiddenGoodsNomenclature.codes))
  }

  one_to_one :chapter_note, primary_key: :to_param

  one_to_many :search_references, key: :referenced_id, primary_key: :short_code, reciprocal: :referenced, conditions: { referenced_class: 'Chapter' },
                                  adder: proc { |search_reference| search_reference.update(referenced_id: short_code, referenced_class: 'Chapter') },
                                  remover: proc { |search_reference| search_reference.update(referenced_id: nil, referenced_class: nil) },
                                  clearer: proc { search_references_dataset.update(referenced_id: nil, referenced_class: nil) }

  many_to_many :guides, left_key: :goods_nomenclature_sid,
                        join_table: :chapters_guides

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
      filter('goods_nomenclatures.goods_nomenclature_item_id LIKE ?', "#{code.to_s.first(2)}00000000")
    end
  end

  # See oplog sequel plugin
  def operation=(op)
    self[:operation] = op.to_s.first.upcase
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
      Sequel.as(depth, :depth)
    ).where(pk_hash)
     .union(Heading.changes_for(depth + 1, ['goods_nomenclature_item_id LIKE ? AND goods_nomenclature_item_id NOT LIKE ?', relevant_headings, '__00______']))
     .union(Commodity.changes_for(depth + 1, ['goods_nomenclature_item_id LIKE ? AND goods_nomenclature_item_id NOT LIKE ?', relevant_commodities, '____000000']))
     .union(Measure.changes_for(depth + 1, ['goods_nomenclature_item_id LIKE ?', relevant_commodities]))
     .from_self
     .where(Sequel.~(operation_date: nil))
     .tap! { |criteria|
      # if Chapter did not come from initial seed, filter by its
      # create/update date
      criteria.where { |o| o.>=(:operation_date, operation_date) } unless operation_date.blank?
    }
     .limit(TradeTariffBackend.change_count)
     .order(Sequel.desc(:operation_date, nulls: :last), Sequel.desc(:depth))
  end

  private

  def relevant_headings
    "#{short_code}__000000"
  end

  def relevant_commodities
    "#{short_code}________"
  end
end
