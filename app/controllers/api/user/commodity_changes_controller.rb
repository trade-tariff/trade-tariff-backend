module Api
  module User
    class CommodityChangesController < UserController
      def index
        render json: Api::User::CommodityChangesSerializer.new(tariff_changes).serializable_hash
      end

      def show
        render json: Api::User::CommodityChangesSerializer.new(tariff_changes, serializer_options).serializable_hash
      end

      def serializer_options
        {
          include: %w[tariff_changes],
        }
      end

      def tariff_changes
        Api::User::CommodityChangesService.new(current_user, params[:id], actual_date).call
      end
    end
  end
end
