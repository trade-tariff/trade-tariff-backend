module Api
  module Admin
    class RollbacksController < AdminController
      before_action :authenticate_user!
      before_action :collection, only: :index

      def index
        render json: Api::Admin::RollbackSerializer.new(@collection.to_a, serialization_meta).serializable_hash
      end

      def create
        rollback = Rollback.new(rollback_params[:attributes])

        if rollback.valid?
          rollback.save
          render json: Api::Admin::RollbackSerializer.new(rollback, { is_collection: false }).serializable_hash, status: :created, location: api_rollbacks_url
        else
          render json: Api::Admin::ErrorSerializationService.new(rollback).call, status: :unprocessable_content
        end
      end

      private

      def rollback_params
        params.require(:data).permit(:type, attributes: %i[date keep reason user_id])
      end

      def collection
        @collection ||= Rollback.descending.paginate(current_page, per_page)
      end

      def serialization_meta
        {
          meta: {
            pagination: {
              page: current_page,
              per_page:,
              total_count: @collection.pagination_record_count,
            },
          },
        }
      end
    end
  end
end
