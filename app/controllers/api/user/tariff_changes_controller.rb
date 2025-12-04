module Api
  module User
    class TariffChangesController < ApiController
      include PublicUserAuthenticatable

      no_caching

      before_action :authenticate!

      def download
        package = TariffChangesService.generate_report_for(as_of, @current_user)

        return render json: { error: 'No changes found' }, status: :not_found if package.nil?

        filename = "commodity_watch_list_changes_#{as_of.strftime('%Y_%m_%d')}.xlsx"
        send_data package.to_stream.read,
                  type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                  disposition: "attachment; filename=#{filename}"
      end

      private

      def as_of
        if params[:as_of].present?
          Date.parse(params[:as_of])
        else
          Time.zone.yesterday
        end
      end
    end
  end
end
