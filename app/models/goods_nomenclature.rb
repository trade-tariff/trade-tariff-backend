class GoodsNomenclature < Sequel::Model
  VALID_GOODS_NOMENCLATURE_ITEM_ID_LENGTH = 10
  CLASSIFICATION_CHAPTER = '98'.freeze

  extend ActiveModel::Naming
  include Formatter

  set_dataset order(Sequel.asc(:goods_nomenclatures__goods_nomenclature_item_id), Sequel.asc(:goods_nomenclatures__producline_suffix))
  set_primary_key [:goods_nomenclature_sid]

  plugin :time_machine

  plugin :oplog, primary_key: :goods_nomenclature_sid, materialized: true
  plugin :nullable
  plugin :active_model

  plugin :sti, class_determinator: lambda { |record|
    gono_id = record[:goods_nomenclature_item_id].to_s

    if gono_id.ends_with?('00000000')
      'Chapter'
    elsif gono_id.ends_with?('000000') && gono_id.slice(2, 2) != '00'
      'Heading'
    elsif !gono_id.ends_with?('000000')
      # checking its a False class because if :leaf is not assigned, we should
      # continue to assume Commodity as previously done
      #
      # :leaf can be included by the use of `GoodsNomenclature.with_leaf_column`
      record[:producline_suffix] != '80' || record[:leaf].is_a?(FalseClass) ? 'Subheading' : 'Commodity'
    else
      'GoodsNomenclature'
    end
  }

  include GoodsNomenclatures::NestedSet

  one_to_one :chapter, class_name: name, class: self do |_ds|
    Chapter.actual.where(goods_nomenclature_item_id: chapter_code)
  end

  one_to_one :heading, class_name: name, class: self do |_ds|
    Heading.actual.where(goods_nomenclature_item_id: heading_code)
  end

  one_to_many :search_references, key: :goods_nomenclature_sid

  one_to_many :full_chemicals, key: :goods_nomenclature_sid

  many_to_many :guides, left_key: :goods_nomenclature_sid,
                        join_table: :guides_goods_nomenclatures

  one_to_many :goods_nomenclature_indents, key: :goods_nomenclature_sid,
                                           primary_key: :goods_nomenclature_sid,
                                           graph_use_association_block: true do |ds|
    ds.with_actual(GoodsNomenclatureIndent, self)
      .order(Sequel.desc(:goods_nomenclature_indents__validity_start_date))
  end

  many_to_many :goods_nomenclature_descriptions, join_table: :goods_nomenclature_description_periods,
                                                 left_primary_key: :goods_nomenclature_sid,
                                                 left_key: :goods_nomenclature_sid,
                                                 right_key: %i[goods_nomenclature_description_period_sid goods_nomenclature_sid],
                                                 right_primary_key: %i[goods_nomenclature_description_period_sid goods_nomenclature_sid],
                                                 graph_use_association_block: true do |ds|
    ds.with_actual(GoodsNomenclatureDescriptionPeriod, self)
      .order(Sequel.desc(:goods_nomenclature_description_periods__validity_start_date))
      .exclude(description: nil)
  end

  many_to_many :footnotes, join_table: :footnote_association_goods_nomenclatures,
                           left_primary_key: :goods_nomenclature_sid,
                           left_key: :goods_nomenclature_sid,
                           right_key: %i[footnote_type footnote_id],
                           right_primary_key: %i[footnote_type_id footnote_id],
                           order: %i[footnote_type_id footnote_id],
                           allow_eager_graph: true do |ds|
    ds.with_actual(FootnoteAssociationGoodsNomenclature)
  end

  one_to_many :tradeset_descriptions,
              key: :goods_nomenclature_item_id,
              primary_key: :goods_nomenclature_item_id,
              graph_use_association_block: true do |ds|
    ds.with_actual(TradesetDescription)
  end

  def number_indents
    if values.key?(:number_indents)
      values[:number_indents]
    elsif goods_nomenclature_indent.present?
      goods_nomenclature_indent.number_indents
    else
      reload && goods_nomenclature_indent&.number_indents
    end
  end

  delegate :description,
           :description_indexed,
           :description_plain,
           :formatted_description,
           :csv_formatted_description,
           :consigned_from,
           to: :goods_nomenclature_description,
           allow_nil: true

  # Find goods nomenclature where I am the origin (e.g. who succeed me)
  one_to_many :deriving_goods_nomenclature_origins, key: %i[derived_goods_nomenclature_item_id derived_productline_suffix],
                                                    primary_key: %i[goods_nomenclature_item_id producline_suffix],
                                                    class_name: 'GoodsNomenclatureOrigin'

  # Find goods nomenclature that I originate from (e.g. who preceded me)
  one_to_many :goods_nomenclature_origins, key: :goods_nomenclature_sid

  one_to_many :goods_nomenclature_successors, key: %i[absorbed_goods_nomenclature_item_id
                                                      absorbed_productline_suffix],
                                              primary_key: %i[goods_nomenclature_item_id
                                                              producline_suffix]

  one_to_many :export_refund_nomenclatures, key: :goods_nomenclature_sid,
                                            primary_key: :goods_nomenclature_sid,
                                            graph_use_association_block: true do |ds|
    ds.with_actual(ExportRefundNomenclature)
  end

  many_to_many :chemicals, join_table: :chemicals_goods_nomenclatures, left_key: :goods_nomenclature_sid, right_key: :chemical_id

  one_to_one :forum_link, key: :goods_nomenclature_sid,
                          foreign_key: :goods_nomenclature_sid,
                          order: Sequel.desc(:created_at)

  one_to_many :green_lanes_measures, class: 'Measure',
                                     class_namespace: 'GreenLanes',
                                     key: %i[goods_nomenclature_item_id productline_suffix],
                                     primary_key: %i[goods_nomenclature_item_id producline_suffix],
                                     reciprocal: :goods_nomenclature

  dataset_module do
    def non_hidden
      filter(Sequel.~(goods_nomenclatures__goods_nomenclature_item_id: HiddenGoodsNomenclature.codes))
    end

    def non_classifieds
      exclude(chapter_short_code: CLASSIFICATION_CHAPTER)
    end

    def non_grouping
      where(producline_suffix: '80')
    end

    def join_footnotes
      association_right_join(:footnotes)
        .exclude(goods_nomenclatures__goods_nomenclature_item_id: nil)
    end

    def with_footnote_type_id(footnote_type_id)
      return self if footnote_type_id.blank?

      where(footnotes__footnote_type_id: footnote_type_id)
    end

    def with_footnote_id(footnote_id)
      return self if footnote_id.blank?

      where(footnotes__footnote_id: footnote_id)
    end

    def with_footnote_types_and_ids(footnote_types_and_ids)
      return self if footnote_types_and_ids.none?

      conditions = footnote_types_and_ids.map do |type, id|
        Sequel.expr(footnotes__footnote_type_id: type) & Sequel.expr(footnotes__footnote_id: id)
      end
      combined_conditions = conditions.reduce(:|)

      where(combined_conditions)
    end
  end

  def goods_nomenclature_class
    self.class.name
  end

  def cast_to(klass)
    return self if is_a?(klass)

    klass.call(values).tap do |casted|
      associations.each do |association, cached_values|
        casted.associations[association] = cached_values
      end
    end
  end

  def sti_cast
    case goods_nomenclature_class
    when 'Subheading' then cast_to(Subheading)
    when 'Commodity' then cast_to(Commodity)
    else self
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

  def specific_system_short_code
    short_code
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

  def non_grouping?
    producline_suffix == GoodsNomenclatureIndent::NON_GROUPING_PRODUCTLINE_SUFFIX
  end

  def grouping?
    !non_grouping?
  end

  def classified?
    chapter_short_code == CLASSIFICATION_CHAPTER
  end

  def classifiable_goods_nomenclatures
    ancestors.dup.push(self).reverse
  end

  def has_chemicals
    @has_chemicals ||= full_chemicals_dataset.limit(1).any?
  end

  def to_admin_param
    to_param
  end
end
