module Api
  module V2
    class AdditionalCodeTypesController < ApiController
      def index
        render json: Api::V2::AdditionalCodes::AdditionalCodeTypeSerializer.new(additional_code_types, {}).serializable_hash
      end

    private

      def additional_code_types
        AdditionalCodeType.all
      end
    end
  end
end
