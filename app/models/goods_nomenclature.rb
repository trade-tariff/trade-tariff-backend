class GoodsNomenclature < Sequel::Model
  extend ActiveModel::Naming

  set_dataset order(Sequel.asc(:goods_nomenclatures__goods_nomenclature_item_id), Sequel.asc(:goods_nomenclatures__producline_suffix))
  set_primary_key [:goods_nomenclature_sid]

  plugin :time_machine

  plugin :oplog, primary_key: :goods_nomenclature_sid
  plugin :nullable
  plugin :active_model

  plugin :sti, class_determinator: lambda { |record|
    gono_id = record[:goods_nomenclature_item_id].to_s

    if gono_id.ends_with?('00000000')
      'Chapter'
    elsif gono_id.ends_with?('000000') && gono_id.slice(2, 2) != '00'
      'Heading'
    elsif !gono_id.ends_with?('000000')
      'Commodity'
    else
      'GoodsNomenclature'
    end
  }

  one_to_one :chapter, class_name: name, class: self do |_ds|
    Chapter
      .actual
      .where(goods_nomenclature_item_id: chapter_code)
  end

  one_to_one :heading, class_name: name, class: self do |_ds|
    Heading.actual.where(goods_nomenclature_item_id: heading_code)
  end

  one_to_many :search_references, key: :goods_nomenclature_sid

  many_to_many :guides, left_key: :goods_nomenclature_sid,
                        join_table: :guides_goods_nomenclatures

  one_to_many :ancestors, class_name: name, class: self do |_ds|
    if path.present?
      GoodsNomenclature
        .actual
        .where('goods_nomenclature_sid = ANY(?)', Sequel.pg_array(path, :integer))
    else
      GoodsNomenclature.dataset.nullify
    end
  end

  one_to_one :parent, class_name: name, class: self do |_ds|
    parent_sid = !heading? ? path.last : chapter.goods_nomenclature_sid

    if parent_sid.present?
      GoodsNomenclature.actual.where(goods_nomenclature_sid: parent_sid)
    else
      GoodsNomenclature.dataset.nullify
    end
  end

  one_to_many :siblings, class_name: name, class: self do |_ds|
    GoodsNomenclature
      .actual
      .exclude(goods_nomenclature_sid:)
      .where(path:)
  end

  one_to_many :children, class_name: name, class: self do |_ds|
    child_path = Sequel.pg_array(path + [goods_nomenclature_sid], :integer)

    GoodsNomenclature
      .actual
      .where(path: child_path)
  end

  one_to_many :descendants, class_name: name, class: self do |_ds|
    GoodsNomenclature
      .actual
      .where('? = ANY(path)', goods_nomenclature_sid)
  end

  one_to_many :goods_nomenclature_indents, key: :goods_nomenclature_sid,
                                           primary_key: :goods_nomenclature_sid do |ds|
    ds.with_actual(GoodsNomenclatureIndent, self)
      .order(Sequel.desc(:goods_nomenclature_indents__validity_start_date))
  end

  many_to_many :goods_nomenclature_descriptions, join_table: :goods_nomenclature_description_periods,
                                                 left_primary_key: :goods_nomenclature_sid,
                                                 left_key: :goods_nomenclature_sid,
                                                 right_key: %i[goods_nomenclature_description_period_sid goods_nomenclature_sid],
                                                 right_primary_key: %i[goods_nomenclature_description_period_sid goods_nomenclature_sid] do |ds|
    ds.with_actual(GoodsNomenclatureDescriptionPeriod, self)
      .order(Sequel.desc(:goods_nomenclature_description_periods__validity_start_date))
      .exclude(description: nil)
  end

  many_to_many :footnotes, join_table: :footnote_association_goods_nomenclatures,
                           left_primary_key: :goods_nomenclature_sid,
                           left_key: :goods_nomenclature_sid,
                           right_key: %i[footnote_type footnote_id],
                           right_primary_key: %i[footnote_type_id footnote_id] do |ds|
    ds.with_actual(FootnoteAssociationGoodsNomenclature)
  end

  one_to_one :national_measurement_unit_set, key: :cmdty_code,
                                             primary_key: :goods_nomenclature_item_id

  delegate :national_measurement_unit_set_units, to: :national_measurement_unit_set, allow_nil: true

  def number_indents
    if goods_nomenclature_indent.present?
      goods_nomenclature_indent.number_indents
    else
      reload && goods_nomenclature_indent&.number_indents
    end
  end

  delegate :description, :description_indexed, :formatted_description, to: :goods_nomenclature_description, allow_nil: true

  # Find goods nomenclature where I am the origin (e.g. who succeed me)
  one_to_many :derived_goods_nomenclature_origins, key: %i[derived_goods_nomenclature_item_id derived_productline_suffix],
                                                   primary_key: %i[goods_nomenclature_item_id producline_suffix],
                                                   class_name: 'GoodsNomenclatureOrigin'

  # Find goods nomenclature that I originate from (e.g. who preceded me)
  one_to_many :goods_nomenclature_origins, key: :goods_nomenclature_sid

  one_to_many :goods_nomenclature_successors, key: %i[absorbed_goods_nomenclature_item_id
                                                      absorbed_productline_suffix],
                                              primary_key: %i[goods_nomenclature_item_id
                                                              producline_suffix]

  one_to_many :export_refund_nomenclatures, key: :goods_nomenclature_sid,
                                            primary_key: :goods_nomenclature_sid do |ds|
    ds.with_actual(ExportRefundNomenclature)
  end

  many_to_many :chemicals, join_table: :chemicals_goods_nomenclatures, left_key: :goods_nomenclature_sid, right_key: :chemical_id

  one_to_one :forum_link, key: :goods_nomenclature_sid,
                          foreign_key: :goods_nomenclature_sid,
                          order: Sequel.desc(:created_at)

  dataset_module do
    def declarable
      filter(producline_suffix: '80')
    end

    def non_hidden
      filter(Sequel.~(goods_nomenclature_item_id: HiddenGoodsNomenclature.codes))
    end

    def indexable
      where(Sequel.~(goods_nomenclature_item_id: HiddenGoodsNomenclature.codes))
    end
  end

  def goods_nomenclature_class
    @goods_nomenclature_class ||= begin
      class_name = self.class.sti_load(goods_nomenclature_item_id:).class.name

      return class_name unless class_name == 'Commodity'

      Commodity.find(goods_nomenclature_sid:).goods_nomenclature_class
    end
  end

  def goods_nomenclature_indent
    goods_nomenclature_indents.first
  end

  def goods_nomenclature_description
    goods_nomenclature_descriptions.first || NullGoodsNomenclature.new
  end

  def footnote
    footnotes.first
  end

  def id
    goods_nomenclature_sid
  end

  def to_s
    "#{number_indents}: #{goods_nomenclature_item_id}: #{description}"
  end

  def heading_id
    "#{goods_nomenclature_item_id.first(4)}______"
  end

  def chapter_id
    goods_nomenclature_item_id.first(2) + '0' * 8
  end

  def heading_code
    if heading_short_code
      heading_short_code + '0' * 6
    end
  end

  def chapter_code
    if chapter_short_code
      chapter_short_code + '0' * 8
    end
  end

  def code
    goods_nomenclature_item_id
  end

  def bti_url
    'https://www.gov.uk/guidance/check-what-youll-need-to-get-a-legally-binding-decision-on-a-commodity-code'
  end

  def heading?
    !!goods_nomenclature_item_id.match(/\A\d{4}000000\z/)
  end

  def chapter?
    !!goods_nomenclature_item_id.match(/\A\d{2}00000000\z/)
  end

  def declarable?
    children.none? && producline_suffix == GoodsNomenclatureIndent::NON_GROUPING_PRODUCTLINE_SUFFIX
  end

  def classifiable_goods_nomenclatures
    ancestors.dup.push(self).reverse
  end

  def intercept_terms
    Beta::Search::InterceptMessage.all_references[goods_nomenclature_item_id]
  end

  def admin_id
    "#{goods_nomenclature_item_id}-#{producline_suffix}"
  end
end
