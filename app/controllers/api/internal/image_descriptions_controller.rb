module Api
  module Internal
    class ImageDescriptionsController < InternalController
      rescue_from ImageDescription::InvalidUpload do |exception|
        render_error(exception.message, status: :unprocessable_content)
      end

      rescue_from ImageDescription::TooLarge do |exception|
        render_error(exception.message, status: :content_too_large)
      end

      rescue_from ImageDescription::UnsupportedFormat do |exception|
        render_error(exception.message, status: :unsupported_media_type)
      end

      rescue_from ImageDescription::Busy do
        render_error('Image description is busy. Wait a moment and try again.', status: :service_unavailable)
      end

      rescue_from RedisClient::Error, with: :unavailable

      def create
        job = ImageDescription.create(params[:image], request_id: TradeTariffRequest.request_id)
        unless ImageDescriptionWorker.perform_async(job.id)
          job.delete
          return unavailable
        end
        render json: { id: job.id, status: 'queued' }, status: :accepted
      rescue RedisClient::Error
        job&.cleanup
        raise
      end

      def show
        return head :not_found unless params[:id].match?(ImageDescription::ID_PATTERN)

        payload = ImageDescription.new(params[:id]).payload
        return head :not_found unless payload

        render json: payload.slice('id', 'status', 'description', 'uncertainties', 'error')
      end

    private

      def unavailable
        render_error('Image description is temporarily unavailable. Try again or type a description.', status: :service_unavailable)
      end

      def render_error(message, status:)
        serializer = TradeTariffBackend.error_serializer(request)
        render json: serializer.serialized_errors({ error: message }), status: status
      end
    end
  end
end
