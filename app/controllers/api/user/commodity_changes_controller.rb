module Api
  module User
    class CommodityChangesController < ApiController
      include PublicUserAuthenticatable

      no_caching

      before_action :authenticate!

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
        Api::User::CommodityChangesService.new(@current_user, params[:id], as_of).call
      end

      def as_of
        params[:as_of] || Time.zone.yesterday.to_date.to_s
      end
    end
  end
end
