module Api
  module Admin
    class AppliesController < AdminController
      before_action :authenticate_user!
      before_action :collection, only: :index

      def index
        render json: Api::Admin::ApplySerializer.new(@collection.to_a, serialization_meta).serializable_hash
      end

      def create
        apply = Apply.new(apply_params[:attributes])

        if apply.valid?
          apply.save
          render json: Api::Admin::ApplySerializer.new(apply, { is_collection: false }).serializable_hash, status: :created, location: api_applies_url
        else
          render json: Api::Admin::ErrorSerializationService.new(apply).call, status: :unprocessable_entity
        end
      end

      private

      def apply_params
        params.require(:data).permit(:type, attributes: %i[user_id])
      end
    end
  end
end
