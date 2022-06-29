module Search
  class GoodsNomenclatureSerializer < ::Serializer
    def serializable_hash(_opts = {})
      {
        goods_nomenclature_item_id:,
        heading_id: heading_short_code,
        chapter_id: chapter_short_code,
        producline_suffix:,
        goods_nomenclature_class:,
        description:,
        description_indexed:,
        chapter_description:,
        heading_description:,
        search_references:,
        ancestors:,
        validity_start_date:,
        validity_end_date:,
      }
    end

    private

    def goods_nomenclature_class(goods_nomenclature = self)
      class_name = GoodsNomenclature
        .sti_load(goods_nomenclature_item_id: goods_nomenclature.goods_nomenclature_item_id)
        .class
        .name

      if class_name == 'Commodity'
        goods_nomenclature.declarable? ? 'Commodity' : 'Subheading'
      else
        class_name
      end
    end

    def chapter_description
      chapter&.description unless chapter?
    end

    def heading_description
      heading&.description unless heading?
    end

    def search_references
      SearchReference.where(referenced_id:, referenced_class:, productline_suffix: producline_suffix).pluck(:title).join(', ')
    end

    def referenced_id
      case referenced_class
      when 'Chapter' then chapter_id
      when 'Heading' then heading_id
      else
        goods_nomenclature_item_id
      end
    end

    def referenced_class
      @referenced_class ||= goods_nomenclature_class
    end

    def ancestors
      super.map do |ancestor|
        {
          goods_nomenclature_item_id: ancestor.goods_nomenclature_item_id,
          productline_suffix: ancestor.producline_suffix,
          goods_nomenclature_class: goods_nomenclature_class(ancestor),
          description: ancestor.description,
        }
      end
    end

    def validity_start_date
      super&.iso8601
    end

    def validity_end_date
      super&.iso8601
    end
  end
end
