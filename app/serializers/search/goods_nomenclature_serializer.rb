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

        # Searchable fields
        description:,
        ancestor_descriptions:,
        search_references: search_references_part,
        labels: labels_part,
      }.compact
    end

    private

    def description
      SearchNegationService.new(classification_description.to_s).call
    end

    def ancestor_descriptions
      ancestors.filter_map { |ancestor|
        next if ancestor.description_indexed.blank?

        ancestor.description_indexed
      }.join(' ')
    end

    def search_references_part
      return if search_references.empty?

      search_references.map do |ref|
        SearchNegationService.new(ref.title).call
      end
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
