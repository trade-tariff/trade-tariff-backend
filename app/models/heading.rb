class Heading < GoodsNomenclature
  plugin :oplog, primary_key: :goods_nomenclature_sid, materialized: true
  plugin :elasticsearch

  set_dataset filter('goods_nomenclatures.goods_nomenclature_item_id LIKE ?', '____000000')
              .filter('goods_nomenclatures.goods_nomenclature_item_id NOT LIKE ?', '__00______')
              .order(
                Sequel.asc(:goods_nomenclature_item_id),
                Sequel.asc(:goods_nomenclatures__producline_suffix),
              )

  set_primary_key [:goods_nomenclature_sid]

  include SearchReferenceable

  one_to_one :chapter,
             primary_key: :chapter_short_code,
             key: :chapter_short_code,
             foreign_key: :chapter_short_code,
             graph_use_association_block: true do |ds|
    ds.with_actual(Chapter)
  end

  dataset_module do
    def by_code(code = '')
      filter(goods_nomenclatures__goods_nomenclature_item_id: "#{code.to_s.first(4)}000000")
    end
  end

  delegate :section, :section_id, to: :chapter, allow_nil: true

  # See oplog sequel plugin
  def operation=(operation)
    self[:operation] = operation.to_s.first.upcase
  end

  def short_code
    goods_nomenclature_item_id.first(4)
  end

  # Override to avoid lookup, this is default behaviour for headings.
  def number_indents
    0
  end

  def to_param
    short_code
  end

  def changes(depth = 1)
    operation_klass.select(
      Sequel.as(Sequel.cast_string('Heading'), :model),
      :oid,
      :operation_date,
      :operation,
      Sequel.as(depth, :depth),
    ).where(pk_hash)
     .union(Commodity.changes_for(depth + 1, ['goods_nomenclature_item_id LIKE ? AND goods_nomenclature_item_id NOT LIKE ?', relevant_goods_nomenclature, '____000000']))
     .union(Measure.changes_for(depth + 1, ['goods_nomenclature_item_id LIKE ?', relevant_goods_nomenclature]))
     .from_self
     .where(Sequel.~(operation_date: nil))
     .tap! { |criteria|
      # if Heading did not come from initial seed, filter by its
      # create/update date
      criteria.where { |o| o.>=(:operation_date, operation_date) } if operation_date.present?
    }
     .limit(TradeTariffBackend.change_count)
     .order(Sequel.desc(:operation_date, nulls: :last), Sequel.desc(:depth))
  end

  def self.changes_for(depth = 0, conditions = {})
    operation_klass.select(
      Sequel.as(Sequel.cast_string('Heading'), :model),
      :oid,
      :operation_date,
      :operation,
      Sequel.as(depth, :depth),
    ).where(conditions)
     .limit(TradeTariffBackend.change_count)
     .order(Sequel.desc(:operation_date, nulls: :last))
  end

  private

  def relevant_goods_nomenclature
    "#{short_code}______"
  end
end
