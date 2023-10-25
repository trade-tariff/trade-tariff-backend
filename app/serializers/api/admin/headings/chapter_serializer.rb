module Api
  module Admin
    module Headings
      class ChapterSerializer
        include JSONAPI::Serializer

        set_type :chapter

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_item_id, :producline_suffix, :description
      end
    end
  end
end
