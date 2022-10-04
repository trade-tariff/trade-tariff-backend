module Api
  module V2
    class PreferenceCodesController < ApiController
      def index
        respond_to do |format|
          format.json do
            render json: PreferenceCodeSerializer.new(
              PreferenceCodeList.all
            ).serializable_hash
          end
        end
      end
    end

  end
end
  