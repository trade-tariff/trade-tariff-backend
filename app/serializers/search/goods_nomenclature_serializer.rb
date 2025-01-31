module Search
  class GoodsNomenclatureSerializer < ::Serializer
    def serializable_hash(_opts = {})
      commodity_attributes = {
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

      commodity_attributes[:search_references] = search_references_part if search_references.present?
      commodity_attributes
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
  end
end
