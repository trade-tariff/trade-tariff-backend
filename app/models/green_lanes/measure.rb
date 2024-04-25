module GreenLanes
  class Measure < Sequel::Model(:green_lanes_measures)
    plugin :timestamps, update_on_create: true
    plugin :auto_validations, not_null: :presence

    many_to_one :category_assessment
    many_to_one :goods_nomenclature, class: 'GoodsNomenclature',
                                     primary_key: %i[goods_nomenclature_item_id producline_suffix],
                                     key: %i[goods_nomenclature_item_id productline_suffix]
  end
end
