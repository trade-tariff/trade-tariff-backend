module Api
  module V2
    module News
      class YearsController < ApiController
        def index
          years = ::News::Item.for_target('updates')
                              .for_service(params[:service])
                              .for_collection(nil) # restrict to stories in published collections
                              .years

          serializer = Api::V2::News::YearSerializer.new(years)

          render json: serializer.serializable_hash
        end

      private

        def set_cache_etag
          fresh_when ::News::Item.latest_change
        end
      end
    end
  end
end
