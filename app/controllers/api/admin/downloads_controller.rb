module Api
  module Admin
    class DownloadsController < AdminController
      def create
        download = Download.new

        if download.valid?
          download.save
          render json: Api::Admin::DownloadSerializer.new(download, { is_collection: false }).serializable_hash, status: :created, location: api_downloads_url
        else
          render json: Api::Admin::ErrorSerializationService.new(download).call, status: :unprocessable_content
        end
      end
    end
  end
end
