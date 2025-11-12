module Api
  module User
    class GroupedMeasureChangesController < ApiController
      include PublicUserAuthenticatable

      no_caching

      before_action :authenticate!

      def index
        render json: serialize(tariff_changes)
      end

      private

      def tariff_changes
        Api::User::GroupedMeasureChangesService.new(@current_user, as_of).call
      end

      def serialize(tariff_changes)
        Api::User::GroupedMeasureChangeSerializer.new(tariff_changes, { include: %i[geographical_area excluded_countries] }).serializable_hash
      end

      def as_of
        params[:as_of] || Time.zone.yesterday.to_date.to_s
      end
    end
  end
end
