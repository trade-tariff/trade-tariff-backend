module Api
  module Admin
    module Sections
      class ChapterSerializer
        include JSONAPI::Serializer

        set_type :chapter

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_sid, :goods_nomenclature_item_id, :headings_from, :headings_to, :description

        attribute :search_references_count do |chapter|
          chapter.search_references.count
        end
      end
    end
  end
end
