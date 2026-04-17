module Api
  module User
    class DataExportController < UserController
      before_action :find_subscription
      before_action :find_data_export, only: %i[show download]

      def show
        render json: serialize
      end

      def create
        data_export = PublicUsers::DataExport.create(
          user_id: current_user.id,
          export_type: data_export_params[:export_type],
          status: PublicUsers::DataExport::QUEUED,
          exporter_args: {
            'subscription_id' => subscription_id,
          },
        )

        DataExportWorker.perform_async(data_export.id)

        render json: Api::User::DataExportSerializer.new(data_export).serializable_hash, status: :accepted
      rescue PublicUsers::UnsupportedFilterServiceError, ArgumentError => e
        render json: serialize_errors(error: e.message), status: :bad_request
      end

      def download
        return render json: { error: 'Export not ready' }, status: :unprocessable_entity unless @data_export.status == PublicUsers::DataExport::COMPLETED

        bytes = Api::User::DataExportService::StorageService.new.download(key: @data_export.s3_key)
        send_data(
          bytes,
          filename: @data_export.file_name || 'data_export.xlsx',
          type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          disposition: 'attachment',
        )
      end

    private

      def serialize
        Api::User::DataExportSerializer.new(@data_export).serializable_hash
      end

      def find_subscription
        @subscription = current_user.subscriptions_dataset.where(uuid: subscription_id).first

        if @subscription.nil?
          render json: { message: 'No subscription ID was provided' }, status: :unauthorized and return
        end
      end

      def find_data_export
        @data_export = PublicUsers::DataExport.dataset
                      .for_user(current_user.id)
                      .where(id: params[:id])
                      .first

        return if @data_export.present?

        render json: { error: 'Export not found' }, status: :not_found
      end

      def subscription_id
        params[:subscription_id]
      end

      def export_type
        params[:export_type]
      end

      def data_export_params
        params.require(:data).require(:attributes).permit(
          :export_type,
        )
      end

      def serialize_errors(errors)
        Api::User::ErrorSerializationService.new.serialized_errors(errors)
      end
    end
  end
end
