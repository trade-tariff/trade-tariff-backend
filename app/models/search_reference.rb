class SearchReference < Sequel::Model
  extend ActiveModel::Naming

  VALID_REFERENCED_CLASSES = %w[
    Chapter
    Heading
    Subheading
    Commodity
  ].freeze

  # search: shown in public search and used by FPO training
  # fpo: used only by FPO training and hidden from public search
  SEARCH_USAGE = 'search'.freeze
  FPO_USAGE = 'fpo'.freeze
  USAGES = [SEARCH_USAGE, FPO_USAGE].freeze
  ALL_USAGES_FILTER = 'all'.freeze
  USAGE_FILTERS = (USAGES + [ALL_USAGES_FILTER]).freeze

  plugin :has_paper_trail

  referenced_setter = proc do |referenced|
    if referenced.present?
      set(
        referenced_class: referenced.goods_nomenclature_class,
        productline_suffix: referenced.producline_suffix,
        goods_nomenclature_item_id: referenced.goods_nomenclature_item_id,
        goods_nomenclature_sid: referenced.goods_nomenclature_sid,
      )
    end
  end

  many_to_one :referenced,
              key: :goods_nomenclature_sid,
              class: 'GoodsNomenclature',
              reciprocal: :search_references,
              reciprocal_type: :many_to_one,
              setter: referenced_setter do |ds|
    ds.with_actual(GoodsNomenclature)
      .with_leaf_column
  end

  self.raise_on_save_failure = false

  module DatasetMethods
    def admin_export
      sr = Sequel[:search_references]
      lbl = Sequel[:goods_nomenclature_labels]

      left_join(:goods_nomenclature_labels, lbl[:goods_nomenclature_sid] => sr[:goods_nomenclature_sid])
        .select_all(:search_references)
        .select_append(
          lbl[:description].as(:label_description),
          lbl[:synonyms].as(:label_synonyms),
          lbl[:colloquial_terms].as(:label_colloquial_terms),
          lbl[:known_brands].as(:label_known_brands),
          lbl[:stale].as(:label_stale),
          lbl[:needs_review].as(:label_needs_review),
          lbl[:approved].as(:label_approved),
          lbl[:manually_edited].as(:label_manually_edited),
          lbl[:expired].as(:label_expired),
        )
        .order(sr[:goods_nomenclature_item_id], sr[:productline_suffix], sr[:title], sr[:id])
    end
  end

  dataset_module do
    include DatasetMethods

    def by_title
      order(Sequel.asc(:title))
    end

    def for_letter(letter)
      where(Sequel.ilike(:title, "#{letter}%")).by_title
    end

    def indexable
      for_search
    end

    def for_search
      where(usage: SEARCH_USAGE)
    end

    def for_fpo
      where(usage: FPO_USAGE)
    end

    # A blank filter excludes FPO references. Use 'all' to include every usage.
    def for_usage(filter)
      filter = filter.presence || SEARCH_USAGE
      filter == ALL_USAGES_FILTER ? self : where(usage: filter)
    end
  end

  def referenced_id
    referenced.to_param
  end

  def referenced_class
    referenced&.goods_nomenclature_class || super
  end

  def title_indexed
    SearchNegationService.new(title).call
  end

  def initialize_set(values)
    super
    self.usage ||= SEARCH_USAGE
  end

  def validate
    super

    errors.add(:referenced_class, 'has to be associated to Chapter/Heading/Subheading/Commodity') unless VALID_REFERENCED_CLASSES.include?(referenced_class)
    errors.add(:title, 'missing title') if title.blank?
    errors.add(:productline_suffix, 'missing productline suffix') if productline_suffix.blank?
    errors.add(:usage, "must be one of #{USAGES.join(', ')}") unless USAGES.include?(usage)
  end

  def fpo?
    usage == FPO_USAGE
  end
end
