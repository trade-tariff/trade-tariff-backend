module Api
  module Admin
    module Headings
      class CommoditySerializer
        include JSONAPI::Serializer

        set_type :commodity

        set_id :admin_id

        attributes :description

        attribute :search_references_count do |commodity|
          commodity.search_references.count
        end
      end
    end
  end
end
