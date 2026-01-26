module Search
  class SearchSuggestionsSerializer < ::Serializer
    def serializable_hash(_opts = {})
      attributes = {
        id: goods_nomenclature_sid,
        description: formatted_description,
        goods_nomenclature_item_id:,
        declarable: declarable?,
        validity_start_date:,
        validity_end_date:,
        number_indents:,
        producline_suffix:,
        type: name,
      }

      attributes[:search_references] = search_references_part if search_references.present?
      attributes[:chemicals] = chemicals_part if full_chemicals.present?
      attributes[:labels] = labels_part if goods_nomenclature_label.present?
      attributes
    end

    def name
      record.class.name
    end

    def declarable?
      TimeMachine.now do
        super
      end
    end

    def search_references_part
      return if search_references.empty?

      search_references.map do |search_reference|
        {
          title: search_reference.title,
          reference_class: search_reference.referenced_class,
        }
      end
    end

    def chemicals_part
      return if full_chemicals.empty?

      full_chemicals.map do |chemical|
        {
          cus: chemical.cus,
          cas_rn: chemical.cas_rn,
          name: chemical.name,
        }
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
