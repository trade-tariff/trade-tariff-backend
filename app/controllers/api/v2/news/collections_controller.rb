module Api
  module V2
    module News
      class CollectionsController < ApiController
        def index
          collections = ::News::Collection.all
          serializer = Api::V2::News::CollectionSerializer.new(collections)

          render json: serializer.serializable_hash
        end
      end
    end
  end
end
