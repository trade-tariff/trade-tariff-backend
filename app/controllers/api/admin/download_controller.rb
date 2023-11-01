module Api
  module Admin
    class DownloadController < AdminController
      before_action :authenticate_user!

      def create
        download = Download.new(download_params[:attributes])

        if download.valid?
          download.save
          render json: Api::Admin::DownloadSerializer.new(download, { is_collection: false }).serializable_hash, status: :created, location: api_downloads_url
        else
          render json: Api::Admin::ErrorSerializationService.new(download).call, status: :unprocessable_entity
        end
      end

      private

      def download_params
        params.require(:data).permit(:type, attributes: %i[user_id])
      end
    end
  end
end
