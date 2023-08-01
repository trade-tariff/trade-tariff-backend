module Api
  module V2
    class AdditionalCodesController < ApiController
      def search
        render json: serialized_additional_codes
      end

      private

      def serialized_additional_codes
        Api::V2::AdditionalCodes::AdditionalCodeSerializer.new(
          finder_service.call,
          include: [:goods_nomenclatures],
        ).serializable_hash
      end

      def finder_service
        @finder_service ||= AdditionalCodeFinderService.new(code, type, description)
      end

      def description
        additional_code_search_params[:description]
      end

      def type
        additional_code_search_params[:type]
      end

      def code
        additional_code_search_params[:code]
      end

      def additional_code_search_params
        params.permit(:description, :type, :code)
      end
    end
  end
end
