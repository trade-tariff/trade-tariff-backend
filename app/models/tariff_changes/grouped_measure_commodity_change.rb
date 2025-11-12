module TariffChanges
  class GroupedMeasureCommodityChange
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :goods_nomenclature_item_id, :string
    attribute :count, :integer
    attribute :grouped_measure_change_id, :string

    def id
      "#{grouped_measure_change_id}_#{goods_nomenclature_item_id}"
    end

    def commodity
      @commodity ||= GoodsNomenclature.find(goods_nomenclature_item_id: goods_nomenclature_item_id)
    end

    def grouped_measure_change
      @grouped_measure_change ||= GroupedMeasureChange.from_id(grouped_measure_change_id) if grouped_measure_change_id
    end
  end
end
