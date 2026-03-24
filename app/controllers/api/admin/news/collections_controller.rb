module Api
  module Admin
    module News
      class CollectionsController < AdminController
        include Api::Admin::ResourceActions

        def index
          render json: serialize(::News::Collection.all)
        end

        private

        def serializer_class = Api::Admin::News::CollectionSerializer
        def resource_class = ::News::Collection

        def resource_params
          params.require(:data).require(:attributes).permit(
            :published,
            :priority,
            :description,
            :name,
            :subscribable,
            :slug,
          )
        end
      end
    end
  end
end
