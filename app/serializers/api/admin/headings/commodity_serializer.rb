module Api
  module Admin
    module Headings
      class CommoditySerializer
        include JSONAPI::Serializer

        set_type :commodity

        set_id :admin_id

        attributes :description,
                   :search_references_count

        attribute :declarable, &:fast_declarable?
      end
    end
  end
end
