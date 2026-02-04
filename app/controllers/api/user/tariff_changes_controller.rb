module Api
  module User
    class TariffChangesController < UserController
      def download
        package = TariffChangesService.generate_report_for(actual_date, current_user)

        return render json: { error: 'No changes found' }, status: :not_found if package.nil?

        filename = "commodity_watch_list_changes_#{actual_date.strftime('%Y_%m_%d')}.xlsx"
        send_data package.to_stream.read,
                  type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                  disposition: "attachment; filename=#{filename}"
      end
    end
  end
end
