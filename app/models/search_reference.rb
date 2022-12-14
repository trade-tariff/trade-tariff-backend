class SearchReference < Sequel::Model
  DEFAULT_PRODUCTLINE_SUFFIX = '80'.freeze
  VALID_REFERENCED_CLASSES = %w[Chapter Heading Subheading Commodity].freeze

  extend ActiveModel::Naming

  plugin :active_model
  plugin :elasticsearch
  plugin :auditable

  many_to_one :referenced, reciprocal: :search_references, reciprocal_type: :many_to_one,
                           setter: (proc do |referenced|
                                      if referenced.present?
                                        set(
                                          referenced_id: referenced.to_param.sub(/-\d{2}/, ''),
                                          referenced_class: referenced.class.name,
                                          productline_suffix: referenced.try(:producline_suffix) || DEFAULT_PRODUCTLINE_SUFFIX,
                                        )
                                      end
                                    end),
                           dataset: (proc do
                                       klass = referenced_class.constantize

                                       case klass.name
                                       when 'Chapter'
                                         klass.where(
                                           Sequel.qualify(:goods_nomenclatures, :goods_nomenclature_item_id) => chapter_id,
                                         )
                                       when 'Heading'
                                         klass.where(
                                           Sequel.qualify(:goods_nomenclatures, :goods_nomenclature_item_id) => heading_id,
                                         )
                                       else

                                         klass.where(
                                           Sequel.qualify(:goods_nomenclatures, :goods_nomenclature_item_id) => referenced_id,
                                           Sequel.qualify(:goods_nomenclatures, :producline_suffix) => productline_suffix,
                                         )
                                       end
                                     end)

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

  alias_method :chapter, :referenced
  alias_method :heading, :referenced
  alias_method :subheading, :referenced
  alias_method :commodity, :referenced

  def chapter_id=(chapter_id)
    self.referenced = Chapter.by_code(chapter_id).take if chapter_id.present?
  end

  def heading_id=(heading_id)
    self.referenced = Heading.by_code(heading_id).take if heading_id.present?
  end

  def commodity_id=(commodity_id)
    self.referenced = Commodity.by_code(commodity_id).declarable.take if commodity_id.present?
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

    errors.add(:referenced_id, 'has to be associated to Chapter/Heading/Subheading/Commodity') if referenced_id.blank?
    errors.add(:referenced_class, 'has to be associated to Chapter/Heading/Subheading/Commodity') unless VALID_REFERENCED_CLASSES.include?(referenced_class)
    errors.add(:title, 'missing title') if title.blank?
    errors.add(:productline_suffix, 'missing productline suffix') if productline_suffix.blank?
  end

  def heading_id
    "#{referenced_id}000000"
  end

  def chapter_id
    "#{referenced_id}00000000"
  end

  def referenced_id_number
    referenced_id&.to_i
  end
end
