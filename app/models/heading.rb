class Heading < GoodsNomenclature
  include Declarable

  plugin :oplog, primary_key: :goods_nomenclature_sid
  plugin :elasticsearch

  set_dataset filter('goods_nomenclatures.goods_nomenclature_item_id LIKE ?', '____000000')
              .filter('goods_nomenclatures.goods_nomenclature_item_id NOT LIKE ?', '__00______')
              .order(
                Sequel.asc(:goods_nomenclature_item_id),
                Sequel.asc(:goods_nomenclatures__producline_suffix),
              )

  set_primary_key [:goods_nomenclature_sid]

  one_to_many :commodities, dataset: lambda {
    actual_or_relevant(Commodity)
             .filter('goods_nomenclatures.goods_nomenclature_item_id LIKE ?', heading_id)
             .where(Sequel.~(goods_nomenclatures__goods_nomenclature_item_id: HiddenGoodsNomenclature.codes))
  }

  one_to_many :goods_nomenclatures do |_ds|
    GoodsNomenclature
      .actual
      .filter('goods_nomenclature_item_id LIKE ?', relevant_goods_nomenclature)
      .exclude(goods_nomenclature_item_id:)
      .exclude(goods_nomenclature_item_id: HiddenGoodsNomenclature.codes)
  end

  one_to_one :chapter, dataset: lambda {
    actual_or_relevant(Chapter).filter('goods_nomenclatures.goods_nomenclature_item_id LIKE ?', chapter_id)
  }

  one_to_many :search_references, key: :referenced_id, primary_key: :short_code, reciprocal: :referenced, conditions: { referenced_class: 'Heading' },
                                  adder: proc { |search_reference| search_reference.update(referenced_id: short_code, referenced_class: 'Heading') },
                                  remover: proc { |search_reference| search_reference.update(referenced_id: nil, referenced_class: nil) },
                                  clearer: proc { search_references_dataset.update(referenced_id: nil, referenced_class: nil) }

  dataset_module do
    def by_code(code = '')
      filter('goods_nomenclatures.goods_nomenclature_item_id LIKE ?', "#{code.to_s.first(4)}000000")
    end

    def by_declarable_code(code = '')
      filter(goods_nomenclature_item_id: code.to_s.first(10))
    end

    def declarable
      filter(producline_suffix: '80')
    end

    def non_grouping
      filter { Sequel.~(producline_suffix: '10') }
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

  def uptree
    [self, chapter].compact
  end

  def non_grouping?
    producline_suffix != '10'
  end

  def declarable
    non_grouping? && GoodsNomenclature.actual
                                      .where('goods_nomenclature_item_id LIKE ?', "#{short_code}______")
                                      .where('goods_nomenclature_item_id > ?', goods_nomenclature_item_id)
                                      .none?
  end
  alias_method :declarable?, :declarable

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
