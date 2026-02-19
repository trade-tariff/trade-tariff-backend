module Search
  class GoodsNomenclatureSerializer < ::Serializer
    def serializable_hash(_opts = {})
      {
        # Presentational fields
        goods_nomenclature_sid:,
        goods_nomenclature_item_id:,
        producline_suffix:,
        chapter_short_code:,
        heading_short_code:,
        number_indents:,
        declarable: declarable?,
        goods_nomenclature_class: record.goods_nomenclature_class,
        formatted_description:,
        validity_start_date:,
        validity_end_date:,
        full_description:,
        heading_description:,

        # Searchable fields
        description:,
        ancestor_descriptions:,
        search_references: search_references_part,
        labels: labels_part,
      }.compact
    end

    class << self
      def ancestor_search_reference_cache
        @ancestor_search_reference_cache ||= SearchReference.exclude(productline_suffix: '80').all
      end

      def reset_ancestor_search_reference_cache!
        @ancestor_search_reference_cache = nil
      end
    end

    private

    def description
      SearchNegationService.new(full_description).call
    end

    def full_description
      @full_description ||=
        goods_nomenclature_self_text&.self_text.presence ||
        DescriptionHtmlFormatter.call(record.raw_classification_description)
    end

    def heading_description
      record.heading&.description_html
    end

    def ancestor_descriptions
      ancestors.filter_map { |ancestor|
        ancestor.description_html.presence
      }.join(' ')
    end

    def search_references_part
      all_refs = search_references + ancestor_search_references
      return if all_refs.empty?

      all_refs.map { |ref|
        SearchNegationService.new(ref.title).call
      }.uniq
    end

    def ancestor_search_references
      ancestors = SearchReference.ancestor_item_ids(goods_nomenclature_item_id)
      self.class.ancestor_search_reference_cache.select { |r| ancestors.include?(r.goods_nomenclature_item_id) }
    end

    def labels_part
      return unless goods_nomenclature_label

      labels = goods_nomenclature_label.labels
      return if labels.blank?

      {
        description: labels['description'],
        known_brands: labels['known_brands'],
        colloquial_terms: labels['colloquial_terms'],
        synonyms: labels['synonyms'],
      }.compact_blank
    end
  end
end
