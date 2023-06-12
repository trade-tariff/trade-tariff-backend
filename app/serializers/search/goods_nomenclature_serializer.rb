module Search
  class GoodsNomenclatureSerializer < ::Serializer
    MAX_ANCESTORS = 13

    def serializable_hash(_opts = {})
      TimeMachine.now do
        serializable = {
          id:,
          goods_nomenclature_item_id:,
          heading_id: heading_short_code,
          chapter_id: chapter_short_code,
          producline_suffix:,
          goods_nomenclature_class:,
          description:,
          description_indexed:,
          description_indexed_shingled: description_indexed,
          formatted_description:,
          search_references:,
          search_intercept_terms:,
          ancestors:,
          validity_start_date:,
          validity_end_date:,
          guides:,
          guide_ids:,
          declarable: ns_declarable?,
        }

        1.upto(MAX_ANCESTORS) do |i|
          serializable["ancestor_#{i}_description_indexed"] = send("ancestor_#{i}_description_indexed")
          serializable["ancestor_#{i}_description_indexed_shingled"] = send("ancestor_#{i}_description_indexed")
        end
        serializable.merge(serializable_classifications)
      end
    end

    private

    def search_references
      ancestors.reverse.each_with_object([search_references_for(self)]) { |serialized_ancestor, acc|
        acc.prepend(serialized_ancestor[:search_references])
      }.join(' ')
    end

    def search_intercept_terms
      ancestors.reverse.each_with_object([intercept_terms]) { |serialized_ancestor, acc|
        next if serialized_ancestor[:intercept_terms].blank?

        acc.prepend(serialized_ancestor[:intercept_terms])
      }.join(' ')
    end

    def ancestors
      @ancestors ||= ns_ancestors.map do |ancestor|
        {
          id: ancestor.goods_nomenclature_sid,
          goods_nomenclature_item_id: ancestor.goods_nomenclature_item_id,
          producline_suffix: ancestor.producline_suffix,
          goods_nomenclature_class: ancestor.goods_nomenclature_class,
          description: ancestor.description,
          description_indexed: ancestor.description_indexed,
          formatted_description: ancestor.formatted_description,
          validity_start_date: ancestor.validity_start_date,
          validity_end_date: ancestor.validity_end_date,
          declarable: false,
          score: nil,
          chapter_id: ancestor.chapter_short_code,
          heading_id: ancestor.heading_short_code,
          ancestor_ids: [], # We are not interested in ancestor ancestors
          ancestors: [], # We are not interested in ancestor ancestors
          search_references: search_references_for(ancestor),
          intercept_terms: ancestor.intercept_terms,
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
      @guides ||= heading.guides.map do |guide|
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
      facet_classification.classifications.transform_keys do |facet|
        "filter_#{facet}".to_sym
      end
    end

    def facet_classification
      @facet_classification ||= if ns_declarable?
                                  Beta::Search::FacetClassification::Declarable.build(self)
                                else
                                  Beta::Search::FacetClassification::NonDeclarable.build(self)
                                end
    end

    def search_references_for(goods_nomenclature)
      goods_nomenclature.search_references.map(&:title_indexed).compact.join(' ')
    end
  end
end
