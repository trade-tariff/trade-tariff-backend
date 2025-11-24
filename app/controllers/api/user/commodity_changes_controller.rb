module Api
  module User
    class CommodityChangesController < ApiController
      include PublicUserAuthenticatable

      no_caching

      before_action :authenticate!

      def index
        render json: serialize(tariff_changes)
      end

      def tariff_changes
        Api::User::CommodityChangesService.new(@current_user, as_of).call
      end

      def serialize(tariff_changes)
        Api::User::CommodityChangeSerializer.new(tariff_changes).serializable_hash
      end

      def as_of
        params[:as_of] || Time.zone.yesterday.to_date.to_s
      end
    end
  end
end
