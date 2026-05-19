module Api
  module Internal
    class ProductDescriptionsController < InternalController
      def create
        result = ProductDescriptionFromUrlService.call(product_description_params[:url].to_s)

        if result.success?
          render json: ProductDescriptionSerializer.new(result).serializable_hash
        else
          render json: error_payload(result), status: :unprocessable_content
        end
      end

      private

      def product_description_params
        params.permit(:url)
      end

      def error_payload(result)
        {
          errors: [
            {
              status: '422',
              title: result.error_title,
              detail: result.error_detail,
              source: { pointer: '/data/attributes/url' },
            },
          ],
        }
      end
    end
  end
end
