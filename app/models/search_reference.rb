class SearchReference < Sequel::Model
  VALID_REFERENCED_CLASSES = %w[
    Chapter
    Heading
    Subheading
    Commodity
  ].freeze

  extend ActiveModel::Naming

  plugin :active_model
  plugin :auditable

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

  dataset_module do
    def by_title
      order(Sequel.asc(:title))
    end

    def for_letter(letter)
      where(Sequel.ilike(:title, "#{letter}%")).by_title
    end

    def for_ancestors(item_ids)
      all_ancestor_ids = item_ids.flat_map { |id| SearchReference.ancestor_item_ids(id) }.uniq
      where(Sequel[:search_references][:goods_nomenclature_item_id] => all_ancestor_ids)
    end

    def indexable
      self
    end
  end

  # Returns ancestor goods_nomenclature_item_ids for a given item_id.
  # E.g. '8418219910' => ['8400000000', '8418000000', '8418210000', '8418219900']
  def self.ancestor_item_ids(item_id)
    (2..8).step(2).map { |n| item_id[0...n].ljust(10, '0') }
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

  def validate
    super

    errors.add(:referenced_class, 'has to be associated to Chapter/Heading/Subheading/Commodity') unless VALID_REFERENCED_CLASSES.include?(referenced_class)
    errors.add(:title, 'missing title') if title.blank?
    errors.add(:productline_suffix, 'missing productline suffix') if productline_suffix.blank?
  end
end
