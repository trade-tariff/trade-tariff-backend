module Search
  class GoodsNomenclatureSerializer < ::Serializer
    def serializable_hash(_opts = {})
      {
        id:,
        goods_nomenclature_item_id:,
        heading_id: heading_short_code,
        chapter_id: chapter_short_code,
        producline_suffix:,
        goods_nomenclature_class:,
        description:,
        description_indexed:,
        search_references:,
        ancestors:,
        validity_start_date:,
        validity_end_date:,
        ancestor_1_description_indexed:, # Chapter
        ancestor_2_description_indexed:, # Heading
        ancestor_3_description_indexed:,
        ancestor_4_description_indexed:,
        ancestor_5_description_indexed:,
        ancestor_6_description_indexed:,
        ancestor_7_description_indexed:,
        ancestor_8_description_indexed:,
        ancestor_9_description_indexed:,
        ancestor_10_description_indexed:,
        ancestor_11_description_indexed:,
        ancestor_12_description_indexed:,
        ancestor_13_description_indexed:,
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
      @ancestors ||= super.map do |ancestor|
        {
          id: ancestor.goods_nomenclature_sid,
          goods_nomenclature_item_id: ancestor.goods_nomenclature_item_id,
          producline_suffix: ancestor.producline_suffix,
          goods_nomenclature_class: goods_nomenclature_class(ancestor),
          description: ancestor.description,
          description_indexed: ancestor.description_indexed,
        }
      end
    end

    def validity_start_date
      super&.iso8601
    end

    def validity_end_date
      super&.iso8601
    end

    def ancestor_1_description_indexed
      ancestors[0].try(:[], :description_indexed)
    end

    def ancestor_2_description_indexed
      ancestors[1].try(:[], :description_indexed)
    end

    def ancestor_3_description_indexed
      ancestors[2].try(:[], :description_indexed)
    end

    def ancestor_4_description_indexed
      ancestors[3].try(:[], :description_indexed)
    end

    def ancestor_5_description_indexed
      ancestors[4].try(:[], :description_indexed)
    end

    def ancestor_6_description_indexed
      ancestors[5].try(:[], :description_indexed)
    end

    def ancestor_7_description_indexed
      ancestors[6].try(:[], :description_indexed)
    end

    def ancestor_8_description_indexed
      ancestors[7].try(:[], :description_indexed)
    end

    def ancestor_9_description_indexed
      ancestors[8].try(:[], :description_indexed)
    end

    def ancestor_10_description_indexed
      ancestors[9].try(:[], :description_indexed)
    end

    def ancestor_11_description_indexed
      ancestors[10].try(:[], :description_indexed)
    end

    def ancestor_12_description_indexed
      ancestors[11].try(:[], :description_indexed)
    end

    def ancestor_13_description_indexed
      ancestors[12].try(:[], :description_indexed)
    end
  end
end
