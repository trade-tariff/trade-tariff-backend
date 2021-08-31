class SearchReference < Sequel::Model
  extend ActiveModel::Naming

  plugin :active_model
  plugin :elasticsearch
  plugin :auditable

  many_to_one :referenced, reciprocal: :search_references, reciprocal_type: :many_to_one,
                           setter: (proc do |referenced|
                                      if referenced.present?
                                        self.set(
                                          referenced_id: referenced.to_param,
                                          referenced_class: referenced.class.name
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
                                           Sequel.qualify(:goods_nomenclatures, :goods_nomenclature_item_id) => chapter_id
                                         )
                                       when 'Heading'
                                         klass.where(
                                           Sequel.qualify(:goods_nomenclatures, :goods_nomenclature_item_id) => heading_id
                                         )
                                       when 'Commodity'
                                         klass.where(
                                           Sequel.qualify(:goods_nomenclatures, :goods_nomenclature_item_id) => commodity_id
                                         )
                                       end
                                     end),
                           eager_loader: (proc do |eo|
                                            id_map = {}
                                            eo[:rows].each do |search_reference|
                                              search_reference.associations[:referenced] = nil
                                              ((id_map[search_reference.referenced_class] ||= {})[search_reference.referenced_id] ||= []) << search_reference
                                            end
                                            id_map.each do |klass_name, id_map|
                                              klass = klass_name.constantize
                                              if klass_name == 'Section'
                                                klass.where(klass.primary_key => id_map.keys).all do |ref|
                                                  id_map[ref.pk.to_s].each do |search_reference|
                                                    search_reference.associations[:referenced] = ref
                                                  end
                                                end
                                              else

                                                pattern = case klass_name
                                                          when 'Chapter'
                                                            id_map.keys.map { |key| "#{key}________" }.join('|')
                                                          when 'Heading'
                                                            id_map.keys.map { |key| "#{key}______" }.join('|')
                                                          when 'Commodity'
                                                            id_map.keys.join('|')
                                                          end

                                                klass.where("goods_nomenclatures.goods_nomenclature_item_id SIMILAR TO '#{pattern}'").all do |ref|
                                                  id_map[ref.short_code].each do |search_reference|
                                                    search_reference.associations[:referenced] = ref
                                                  end
                                                end
                                              end
                                            end
                                          end)

  many_to_one :section do |_ds|
    referenced
  end

  self.raise_on_save_failure = false

  dataset_module do
    def heading_id
      1
    end

    def by_title
      order(Sequel.asc(:title))
    end

    def for_letter(letter)
      where(Sequel.ilike(:title, "#{letter}%"))
    end

    def for_chapters
      where(referenced_class: 'Chapter')
    end

    def for_chapter(chapter)
      for_chapters.where(referenced_id: chapter.to_param)
    end

    def for_headings
      where(referenced_class: 'Heading')
    end

    def for_heading(heading)
      for_headings.where(referenced_id: heading.to_param)
    end

    def for_sections
      where(referenced_class: 'Section')
    end

    def for_section(section)
      for_sections.where(referenced_id: section.to_param)
    end

    def for_commodities
      where(referenced_class: 'Commodity')
    end

    def for_commodity(commodity)
      for_commodities.where(referenced_id: commodity.to_param)
    end

    def indexable
      self
    end
  end

  alias :section= :referenced=
  alias :chapter= :referenced=
  alias :heading= :referenced=
  alias :commodity= :referenced=
  alias :heading :referenced
  alias :chapter :referenced
  alias :section :referenced
  alias :commodity :referenced

  def chapter_id=(chapter_id)
    self.referenced = Chapter.by_code(chapter_id).take if chapter_id.present?
  end

  def heading_id=(heading_id)
    self.referenced = Heading.by_code(heading_id).take if heading_id.present?
  end

  def section_id=(section_id)
    self.referenced = Section.with_pk(section_id) if section_id.present?
  end

  def commodity_id=(commodity_id)
    self.referenced = Commodity.by_code(commodity_id).declarable.take if commodity_id.present?
  end

  def validate
    super

    errors.add(:reference_id, 'has to be associated to Section/Chapter/Heading') if referenced_id.blank?
    errors.add(:reference_class, 'has to be associated to Section/Chapter/Heading') if referenced_id.blank?
    errors.add(:title, 'missing title') if title.blank?
  end

  def section_id
    referenced_id
  end

  def heading_id
    "#{referenced_id}000000"
  end

  def chapter_id
    "#{referenced_id}00000000"
  end

  def commodity_id
    referenced_id
  end

  def referenced_id_number
    referenced_id&.to_i
  end
end
