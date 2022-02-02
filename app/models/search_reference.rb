class SearchReference < Sequel::Model
  DEFAULT_PRODUCTLINE_SUFFIX = '80'.freeze

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
                                       when 'Section'
                                         klass.where(klass.primary_key => referenced_id)
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
      where(Sequel.ilike(:title, "#{letter}%"))
    end

    def indexable
      self
    end
  end

  alias_method :section, :referenced
  alias_method :chapter, :referenced
  alias_method :heading, :referenced
  alias_method :subheading, :referenced
  alias_method :commodity, :referenced

  def section_id=(section_id)
    self.referenced = Section.with_pk(section_id) if section_id.present?
  end

  def chapter_id=(chapter_id)
    self.referenced = Chapter.by_code(chapter_id).take if chapter_id.present?
  end

  def heading_id=(heading_id)
    self.referenced = Heading.by_code(heading_id).take if heading_id.present?
  end

  def commodity_id=(commodity_id)
    self.referenced = Commodity.by_code(commodity_id).declarable.take if commodity_id.present?
  end

  def validate
    super

    errors.add(:reference_id, 'has to be associated to Section/Chapter/Heading') if referenced_id.blank?
    errors.add(:reference_class, 'has to be associated to Section/Chapter/Heading') if referenced_id.blank?
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
