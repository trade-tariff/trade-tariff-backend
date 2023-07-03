module Search
  class BulkSearchIndex < ::SearchIndex
    include PointInTimeIndex

    def dataset_heading(heading_short_code)
      GoodsNomenclature
        .actual
        .where(heading_short_code:)
        .ns_declarable
        .eager(*eager_load)
        .all
    end

    def eager_load
      [
        :goods_nomenclature_descriptions,
        :search_references,
        :ns_children,
        { ns_ancestors: %i[search_references goods_nomenclature_descriptions] },
      ]
    end

    # TODO: Implement me
    def definition; end

    # TODO: Implement me
    def serialize_record(_record)
      'serialized_entry'
    end
  end
end
