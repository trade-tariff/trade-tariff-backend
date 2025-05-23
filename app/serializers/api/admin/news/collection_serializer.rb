module Api
  module Admin
    module News
      class CollectionSerializer
        include JSONAPI::Serializer

        set_type :news_collection

        set_id :id

        attributes :name, :slug, :created_at, :updated_at, :description, :priority, :published, :subscribable
      end
    end
  end
end
