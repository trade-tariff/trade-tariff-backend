module Api
  module V2
    module GoodsNomenclatures
      class GoodsNomenclatureExtendedSerializer
        include JSONAPI::Serializer

        set_type :goods_nomenclature
        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_item_id, :goods_nomenclature_sid, :producline_suffix, :description, :number_indents
        attribute :href do |c|
          GoodsNomenclaturesController.api_path_builder(c, check_for_subheadings: true)
        end

        attributes :formatted_description, :validity_start_date, :validity_end_date
        attribute :declarable, &:declarable?
        attribute :hierarchical_description, &:hierarchical_description

        belongs_to :parent, record_type: :goods_nomenclature, &:parent
      end
    end
  end
end
