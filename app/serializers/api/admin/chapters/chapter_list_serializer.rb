module Api
  module Admin
    module Chapters
      class ChapterListSerializer
        include JSONAPI::Serializer

        set_type :chapter

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_sid,
                   :goods_nomenclature_item_id,
                   :producline_suffix
      end
    end
  end
end
