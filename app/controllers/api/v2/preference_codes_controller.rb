module Api
  module V2
    class PreferenceCodesController < ApiController
      def index
        render json: PreferenceCodeSerializer.new(
          PreferenceCodeList.all,
        ).serializable_hash
      end
    end
  end
end
