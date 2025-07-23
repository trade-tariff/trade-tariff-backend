module Api
  module V2
    class PreferenceCodesController < ApiController
      def index
        render json: preference_codes
      end

      def show
        render json: preference_code
      end

      private

      def preference_codes
        PreferenceCodeSerializer.new(PreferenceCode.all).serializable_hash
      end

      def preference_code
        Api::V2::PreferenceCodeSerializer.new(PreferenceCode.take(params[:id])).serializable_hash
      end
    end
  end
end
