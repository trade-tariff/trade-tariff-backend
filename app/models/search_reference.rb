class SearchReference < Sequel::Model
  DEFAULT_PRODUCTLINE_SUFFIX = '80'.freeze
  VALID_REFERENCED_CLASSES = %w[Chapter Heading Subheading Commodity].freeze

  extend ActiveModel::Naming

  plugin :active_model
  plugin :elasticsearch
  plugin :auditable

  referenced_setter = proc do |referenced|
    if referenced.present?
      set(
        referenced_id: referenced.to_param.sub(/-\d{2}/, ''),
        referenced_class: referenced.class.name,
        productline_suffix: referenced.producline_suffix,
        goods_nomenclature_item_id: referenced.goods_nomenclature_item_id,
        goods_nomenclature_sid: referenced.goods_nomenclature_sid,
      )
    end
  end

  referenced_dataset = proc do
    klass = referenced_class.constantize
    klass.actual.where(goods_nomenclature_sid:)
  end

  many_to_one :referenced, reciprocal: :search_references, reciprocal_type: :many_to_one, setter: referenced_setter, dataset: referenced_dataset

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

  def resource_path
    path = case referenced_class
           when 'Chapter'
             '/chapters/:id'
           when 'Heading'
             '/headings/:id'
           when 'Subheading'
             '/subheadings/:id'
           else
             '/commodities/:id'
           end

    path.sub(':id', referenced.to_param)
  end

  def validate
    super

    errors.add(:referenced_class, 'has to be associated to Chapter/Heading/Subheading/Commodity') unless VALID_REFERENCED_CLASSES.include?(referenced_class)
    errors.add(:title, 'missing title') if title.blank?
    errors.add(:productline_suffix, 'missing productline suffix') if productline_suffix.blank?
  end
end
