module Search
  class GoodsNomenclatureSerializer < ::Serializer
    MAX_ANCESTORS = 13

    def serializable_hash(_opts = {})
      serializable = {
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
        guides:,
        guide_ids:,
        declarable: declarable?,
      }

      serializable.merge(serializable_classifications)
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

    def guides
      # NB: We're not currently interested in chapter guides and prefer more specific guidance currently
      return [] if chapter?

      heading.guides.map do |guide|
        {
          id: guide.id,
          title: guide.title,
          image: guide.image,
          url: guide.url,
          strapline: guide.strapline,
        }
      end
    end

    def guide_ids
      guides.map { |guide| guide[:id] }
    end

    1.upto(MAX_ANCESTORS) do |ancestor_number|
      define_method("ancestor_#{ancestor_number}_description_indexed") do
        ancestors[ancestor_number - 1].try(:[], :description_indexed)
      end
    end

    def serializable_classifications
      facet_classification.classifications.each_with_object({}) do |(facet, classification_value), acc|
        acc["filter_#{facet}".to_sym] = classification_value
      end
    end

    def facet_classification
      @facet_classification ||= if declarable?
                                  Beta::Search::FacetClassification::Declarable.build(self)
                                else
                                  Beta::Search::FacetClassification::NonDeclarable.build(self)
                                end
    end
  end
end
