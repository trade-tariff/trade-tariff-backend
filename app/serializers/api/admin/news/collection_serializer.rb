module Api
  module Admin
    module News
      class CollectionSerializer
        include JSONAPI::Serializer

        set_type :news_collection

        set_id :id

        attributes :name, :created_at, :updated_at
      end
    end
  end
end
