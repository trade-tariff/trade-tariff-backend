module Api
  module V2
    module News
      class CollectionSerializer
        include JSONAPI::Serializer

        set_type :news_collection

        set_id :id

        attributes :name, :slug, :description, :priority
      end
    end
  end
end
