module Api
  module V2
    module News
      class YearsController < ApiController
        def index
          years = ::News::Item.for_target('updates')
                              .for_service(params[:service])
                              .years

          serializer = Api::V2::News::YearSerializer.new(years)

          render json: serializer.serializable_hash
        end
      end
    end
  end
end