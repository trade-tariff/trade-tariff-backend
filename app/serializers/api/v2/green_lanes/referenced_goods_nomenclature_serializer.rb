module Api
  module V2
    module GreenLanes
      class ReferencedGoodsNomenclatureSerializer
        include JSONAPI::Serializer

        set_type :goods_nomenclature

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_sid,
                   :goods_nomenclature_item_id,
                   :formatted_description,
                   :description,
                   :number_indents,
                   :producline_suffix,
                   :validity_start_date,
                   :validity_end_date,
                   :parent_sid,
                   :supplementary_measure_unit

        has_many :licences, serializer: CertificateSerializer
      end
    end
  end
end
