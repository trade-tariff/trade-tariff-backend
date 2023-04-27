module Api
  module V2
    module Chapters
      class HeadingSerializer
        include JSONAPI::Serializer

        set_type :heading

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_sid, :goods_nomenclature_item_id
        attribute :declarable, &:ns_declarable?

        attributes :description, :producline_suffix, :leaf
        attributes :description_plain, :formatted_description,
                   :validity_start_date, :validity_end_date

        has_many :children, record_type: 'heading',
                            serializer: Api::V2::Chapters::HeadingLeafSerializer
      end
    end
  end
end
