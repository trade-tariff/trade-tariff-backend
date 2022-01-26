class Commodity < GoodsNomenclature
  include Declarable

  plugin :oplog, primary_key: :goods_nomenclature_sid
  plugin :elasticsearch

  set_dataset filter('goods_nomenclatures.goods_nomenclature_item_id NOT LIKE ?', '____000000')
              .order(Sequel.asc(:goods_nomenclatures__goods_nomenclature_item_id),
                     Sequel.asc(:goods_nomenclatures__producline_suffix),
                     Sequel.asc(:goods_nomenclatures__goods_nomenclature_sid))

  set_primary_key [:goods_nomenclature_sid]

  def admin_id
    "#{goods_nomenclature_item_id}-#{producline_suffix}"
  end

  one_to_one :heading, dataset: -> {
    actual_or_relevant(Heading)
           .filter('goods_nomenclatures.goods_nomenclature_item_id LIKE ?', heading_id)
           .filter(producline_suffix: '80')
  }

  one_to_one :chapter, dataset: -> {
    actual_or_relevant(Chapter)
           .filter('goods_nomenclatures.goods_nomenclature_item_id LIKE ?', chapter_id)
  }

  one_to_many :overview_measures, key: {}, primary_key: {}, dataset: -> {
    measures_dataset.filter(measures__measure_type_id: MeasureType::OVERVIEW_MEASURE_TYPES)
  }, class_name: 'Measure'

  one_to_many :search_references, key: :referenced_id, primary_key: :code, reciprocal: :referenced, conditions: { referenced_class: 'Commodity' },
                                  adder: proc { |search_reference| search_reference.update(referenced_id: code, productline_suffix: producline_suffix, referenced_class: 'Commodity') },
                                  remover: proc { |search_reference| search_reference.update(referenced_id: nil, referenced_class: nil, productline_suffix: nil) },
                                  clearer: proc { search_references_dataset.update(referenced_id: nil, referenced_class: nil, productline_suffix: nil) } do |dataset|
                                    dataset.where(productline_suffix: producline_suffix)
                                  end

  delegate :section, :section_id, to: :chapter, allow_nil: true

  dataset_module do
    def by_code(code = '')
      filter(goods_nomenclature_item_id: code.to_s.first(10))
    end

    def by_productline_suffix(productline_suffix)
      filter(producline_suffix: productline_suffix)
    end

    def declarable
      filter(producline_suffix: '80')
    end
  end

  # See oplog sequel plugin
  def operation=(op)
    self[:operation] = op.to_s.first.upcase
  end

  def ancestors
    # TODO: we need to create more efficient and unambiguous way to get ancestors
    # because getting Commodities with goods_nomenclature_item_id LIKE 'something'
    # can fetch Commodities not from ancestors tree.
    Commodity.select(Sequel.expr(:goods_nomenclatures).*)
      .eager(:goods_nomenclature_indents,
             :goods_nomenclature_descriptions)
      .join_table(:inner,
                  GoodsNomenclatureIndent
                           .select(:goods_nomenclature_indents__goods_nomenclature_sid,
                                   :goods_nomenclature_indents__goods_nomenclature_item_id,
                                   :goods_nomenclature_indents__number_indents)
                           .with_actual(GoodsNomenclature)
                           .join(:goods_nomenclatures, goods_nomenclature_indents__goods_nomenclature_sid: :goods_nomenclatures__goods_nomenclature_sid)
                           .where('goods_nomenclature_indents.goods_nomenclature_item_id LIKE ?', heading_id)
                           .where('goods_nomenclature_indents.goods_nomenclature_item_id <= ?', goods_nomenclature_item_id)
                           .order(Sequel.desc(:goods_nomenclature_indents__validity_start_date),
                                  Sequel.desc(:goods_nomenclature_indents__goods_nomenclature_item_id))
                           .from_self
                           .group(:goods_nomenclature_sid, :goods_nomenclature_item_id, :number_indents)
                           .from_self
                           .where('number_indents < ?', goods_nomenclature_indent.number_indents),
                  t1__goods_nomenclature_sid: :goods_nomenclatures__goods_nomenclature_sid,
                  t1__goods_nomenclature_item_id: :goods_nomenclatures__goods_nomenclature_item_id)
      .order(Sequel.desc(:goods_nomenclatures__goods_nomenclature_item_id))
      .all
      .group_by(&:number_indents)
      .map(&:last)
      .map(&:first)
      .reverse
      .sort_by(&:number_indents)
      .select { |a| a.number_indents < goods_nomenclature_indent.number_indents }
  end

  def declarable?
    producline_suffix == '80' && children.none?
  end

  def uptree
    @_uptree ||= [ancestors, heading, chapter, self].flatten.compact
  end

  def children
    func = Proc.new {
      GoodsNomenclatureMapper.new(
        heading.commodities_dataset
                .eager(:goods_nomenclature_indents, :goods_nomenclature_descriptions)
                .all
      ).all
        .detect do |item|
        item.goods_nomenclature_sid == goods_nomenclature_sid
      end.try(:children) || []
    }

    func.call
  end

  def to_param
    code
  end

  def code
    goods_nomenclature_item_id
  end

  def self.changes_for(depth = 0, conditions = {})
    operation_klass.select(
      Sequel.as(Sequel.cast_string('Commodity'), :model),
      :oid,
      :operation_date,
      :operation,
      Sequel.as(depth, :depth)
    ).where(conditions)
     .where(Sequel.~(operation_date: nil))
     .limit(TradeTariffBackend.change_count)
     .order(Sequel.desc(:operation_date, nulls: :last))
  end

  def changes(depth = 1)
    operation_klass.select(
      Sequel.as(Sequel.cast_string('GoodsNomenclature'), :model),
      :oid,
      :operation_date,
      :operation,
      Sequel.as(depth, :depth)
    ).where(pk_hash)
     .union(
       Measure.changes_for(
         depth + 1,
         Sequel.qualify(:measures_oplog, :goods_nomenclature_item_id) => goods_nomenclature_item_id
       )
     )
     .from_self
     .where(Sequel.~(operation_date: nil))
     .tap! { |criteria|
      # if Commodity did not come from initial seed, filter by its
      # create/update date
      criteria.where { |o| o.>=(:operation_date, operation_date) } unless operation_date.blank?
    }
     .limit(TradeTariffBackend.change_count)
     .order(Sequel.desc(:operation_date, nulls: :last), Sequel.desc(:depth))
  end

  def traverse_children(&block)
    yield self

    children.each { |child| child.traverse_children(&block) }
  end
end
