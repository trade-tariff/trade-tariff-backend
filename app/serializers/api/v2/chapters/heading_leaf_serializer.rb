class Api::V2::Chapters::HeadingLeafSerializer
  include JSONAPI::Serializer

  set_type :heading

  set_id :goods_nomenclature_sid

  attributes :goods_nomenclature_sid, :goods_nomenclature_item_id,
             :declarable, :description, :producline_suffix, :leaf,
             :description_plain, :formatted_description
end
