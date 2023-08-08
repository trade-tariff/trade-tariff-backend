class Api::V2::Chapters::HeadingLeafSerializer
  include JSONAPI::Serializer

  set_type :heading

  set_id :goods_nomenclature_sid

  attribute :goods_nomenclature_sid, :goods_nomenclature_item_id

  attribute :declarable, &:declarable?

  attributes :description, :producline_suffix, :leaf
  attributes :description_plain, :formatted_description
end
