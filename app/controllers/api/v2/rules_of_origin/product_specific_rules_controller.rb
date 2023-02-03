module Api
  module V2
    module RulesOfOrigin
      class ProductSpecificRulesController < ApiController
        def index
          schemes = []

          render json: serializer(schemes).serializable_hash
        end

      private

        def serializer(schemes)
          Api::V2::RulesOfOrigin::SchemeSerializer.new(schemes)
        end
      end
    end
  end
end
