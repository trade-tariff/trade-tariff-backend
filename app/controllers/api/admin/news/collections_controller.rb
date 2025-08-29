module Api
  module Admin
    module News
      class CollectionsController < AdminController
        before_action :authenticate_user!

        def index
          collections = ::News::Collection.all

          render json: Api::Admin::News::CollectionSerializer.new(collections)
                                                             .serializable_hash
        end

        def show
          news_collection = ::News::Collection.where(id: params[:id]).take

          render json: serialize(news_collection)
        end

        def create
          news_collection = ::News::Collection.new(news_collection_params)

          if news_collection.valid? && news_collection.save
            render json: serialize(news_collection),
                   status: :created
          else
            render json: serialize_errors(news_collection),
                   status: :unprocessable_content
          end
        end

        def update
          news_collection = ::News::Collection.with_pk!(params[:id])
          news_collection.set news_collection_params

          if news_collection.valid? && news_collection.save
            render json: serialize(news_collection),
                   status: :ok
          else
            render json: serialize_errors(news_collection),
                   status: :unprocessable_content
          end
        end

        private

        def news_collection_params
          params.require(:data).require(:attributes).permit(
            :published,
            :priority,
            :description,
            :name,
            :subscribable,
            :slug,
          )
        end

        def serialize(*args)
          Api::Admin::News::CollectionSerializer.new(*args).serializable_hash
        end

        def serialize_errors(news_collection)
          Api::Admin::ErrorSerializationService.new(news_collection).call
        end
      end
    end
  end
end
