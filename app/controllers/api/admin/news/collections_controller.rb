module Api
  module Admin
    module News
      class CollectionsController < ApiController
        before_action :authenticate_user!

        def index
          collections = ::News::Collection.order(:name).to_a

          render json: Api::Admin::News::CollectionSerializer.new(collections)
                                                             .serializable_hash
        end
      end
    end
  end
end
