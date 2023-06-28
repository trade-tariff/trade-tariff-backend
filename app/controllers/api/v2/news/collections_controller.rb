module Api
  module V2
    module News
      class CollectionsController < ApiController
        def index
          collections = ::News::Collection.published.all
          serializer = Api::V2::News::CollectionSerializer.new(collections)

          render json: serializer.serializable_hash
        end

      protected

        def set_cache_etag
          fresh_when ::News::Item.latest_change
        end
      end
    end
  end
end
