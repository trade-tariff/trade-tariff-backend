module Api
  module V2
    class PreferenceCodesController < ApiController
      def index
        respond_to do |format|
          format.json do
            render json: PreferenceCodeSerializer.new(
              PreferenceCode.all,
            ).serializable_hash
          end
        end
      end

      def show
        preference_code = PreferenceCode[params[:id]]

        serializer = Api::V2::PreferenceCodeSerializer.new(preference_code)

        render json: serializer.serializable_hash
      end
    end
  end
end
