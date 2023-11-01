module Api
  module Admin
    class DownloadsController < AdminController
      before_action :authenticate_user!

      def create
        binding.pry
        # Curl example: curl -X POST -H "Content-Type: application/json" -d '{"data":{"type":"download","attributes":{"user_id":1}}}' http://localhost:3000/api/admin/downloads

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
        
        # example in url: http://localhost:3000/api/admin/downloads?data[type]=download&data[attributes][user_id]=1
      end
    end
  end
end
