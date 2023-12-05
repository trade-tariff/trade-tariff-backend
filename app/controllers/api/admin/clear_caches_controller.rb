module Api
  module Admin
    class ClearCachesController < AdminController
      before_action :authenticate_user!

      def create
        clear_cache = ClearCache.new(clear_cache_params[:attributes])

        if clear_cache.valid?
          clear_cache.save
          render json: Api::Admin::ClearCacheSerializer.new(clear_cache).serializable_hash, status: :created
        else
          render json: Api::Admin::ErrorSerializationService.new(clear_cache).call, status: :unprocessable_entity
        end
      end

      private

      def clear_cache_params
        params.require(:data).permit(:type, attributes: %i[user_id])
      end
    end
  end
end
