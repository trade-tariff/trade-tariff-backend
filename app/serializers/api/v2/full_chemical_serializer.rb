module Api
  module V2
    class FullChemicalSerializer
      include JSONAPI::Serializer

      set_type :chemical_substance

      attributes :cus,
                 :goods_nomenclature_sid,
                 :goods_nomenclature_item_id,
                 :producline_suffix,
                 :name,
                 :cas_rn,
                 :nomen
    end
  end
end
