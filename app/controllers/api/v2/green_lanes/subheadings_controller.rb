module Api
  module V2
    module GreenLanes
      class SubheadingsController < ApiController

        def show
          subheading = Subheading.actual.where(goods_nomenclature_item_id: "#{params[:id]}0000", producline_suffix: '80').take
          serializer = Api::V2::GreenLanes::SubheadingSerializer.new(subheading)
          render json: serializer.serializable_hash
        end

      end
    end
  end
end
