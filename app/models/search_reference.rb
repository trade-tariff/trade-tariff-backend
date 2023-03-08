class SearchReference < Sequel::Model
  VALID_REFERENCED_CLASSES = %w[
    Chapter
    Heading
    Subheading
    Commodity
  ].freeze

  extend ActiveModel::Naming

  plugin :active_model
  plugin :elasticsearch
  plugin :auditable

  referenced_setter = proc do |referenced|
    if referenced.present?
      set(
        referenced_class: referenced.class.name,
        productline_suffix: referenced.producline_suffix,
        goods_nomenclature_item_id: referenced.goods_nomenclature_item_id,
        goods_nomenclature_sid: referenced.goods_nomenclature_sid,
      )
    end
  end

  many_to_one :referenced, key: :goods_nomenclature_sid, reciprocal: :search_references, reciprocal_type: :many_to_one, setter: referenced_setter, dataset: proc {
    klass = referenced_class.constantize
    klass.actual.where(goods_nomenclature_sid:)
  }

  self.raise_on_save_failure = false

  dataset_module do
    def by_title
      order(Sequel.asc(:title))
    end

    def for_letter(letter)
      where(Sequel.ilike(:title, "#{letter}%")).by_title
    end

    def indexable
      self
    end
  end

  def referenced_id
    referenced.to_admin_param
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
