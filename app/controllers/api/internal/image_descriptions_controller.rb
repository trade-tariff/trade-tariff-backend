module Api
  module Internal
    class ImageDescriptionsController < InternalController
      before_action :no_store

      def create
        job = ImageDescription.create(params[:image], request_id: TradeTariffRequest.request_id)
        unless ImageDescriptionWorker.perform_async(job.id)
          job.delete
          return unavailable
        end
        render json: { id: job.id, status: 'queued' }, status: :accepted
      rescue ImageDescription::TooLarge => e
        render json: { error: e.message }, status: :content_too_large
      rescue ImageDescription::UnsupportedFormat => e
        render json: { error: e.message }, status: :unsupported_media_type
      rescue ImageDescription::InvalidUpload => e
        render json: { error: e.message }, status: :unprocessable_content
      rescue ImageDescription::Busy
        render json: { error: 'Image description is busy. Wait a moment and try again.' }, status: :service_unavailable
      rescue RedisClient::Error
        job&.cleanup
        unavailable
      end

      def show
        return head :not_found unless params[:id].match?(ImageDescription::ID_PATTERN)

        payload = ImageDescription.new(params[:id]).payload
        return head :not_found unless payload

        render json: payload.slice('id', 'status', 'description', 'uncertainties', 'error')
      rescue RedisClient::Error
        unavailable
      end

    private

      def unavailable
        render json: { error: 'Image description is temporarily unavailable. Try again or type a description.' }, status: :service_unavailable
      end
    end
  end
end
