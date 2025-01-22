module Search
  class GoodsNomenclatureSerializer < ::Serializer
    def serializable_hash(_opts = {})
      commodity_attributes = {
        id: goods_nomenclature_sid,
        goods_nomenclature_item_id:,
        producline_suffix:,
        validity_start_date:,
        validity_end_date:,
        description: formatted_description,
        description_indexed:,
        number_indents:,
        declarable: declarable?,
        ancestor_descriptions:,
      }

      commodity_attributes[:search_references] = search_references_part if search_references.present?
      commodity_attributes[:section] = section_part if section.present?
      commodity_attributes[:chapter] = chapter_part if chapter.present?
      commodity_attributes[:heading] = heading_part if heading.present?

      commodity_attributes
    end

    # Using TimeMachine here preserves our ability to exclude the core document from the search
    # results via the validity_start_date and validity_end_date fields but enables us to use
    # nested set to pull out the ancestor descriptions that apply to the given document on a given day.
    #
    # Nested requires the TimeMachine to be set.
    def description_indexed
      TimeMachine.now do
        classifiable_goods_nomenclatures.map(&:description_indexed).join(' ')
      end
    end

    def declarable?
      TimeMachine.now do
        super
      end
    end

    def ancestor_descriptions
      TimeMachine.now do
        classifiable_goods_nomenclatures.reverse.map(&:description)
      end
    end

    def section_part
      return if section.blank?

      {
        numeral: section.numeral,
        title: section.title,
        position: section.position,
      }
    end

    def chapter_part
      return if chapter.blank?

      {
        goods_nomenclature_sid: chapter.goods_nomenclature_sid,
        goods_nomenclature_item_id: chapter.goods_nomenclature_item_id,
        producline_suffix: chapter.producline_suffix,
        validity_start_date: chapter.validity_start_date,
        validity_end_date: chapter.validity_end_date,
        description: chapter.formatted_description,
        guides: chapter.guides.map do |guide|
          {
            title: guide.title,
            url: guide.url,
          }
        end,
      }
    end

    def heading_part
      return if heading.blank?

      {
        goods_nomenclature_sid: heading.goods_nomenclature_sid,
        goods_nomenclature_item_id: heading.goods_nomenclature_item_id,
        producline_suffix: heading.producline_suffix,
        validity_start_date: heading.validity_start_date,
        validity_end_date: heading.validity_end_date,
        description: heading.formatted_description,
        number_indents: heading.number_indents,
      }
    end

    def search_references_part
      return if search_references.empty?

      search_references.map do |search_reference|
        {
          title: search_reference.title,
          title_indexed: SearchNegationService.new(search_reference.title).call,
          reference_class: search_reference.referenced_class,
        }
      end
    end
  end
end
