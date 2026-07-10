module Api
  module V3
    class CommoditiesController < BaseController
      def show
        commodity = Commodity.actual.non_hidden.declarable.by_code(params[:id]).take
        raise Sequel::RecordNotFound, "Commodity #{params[:id]} not found" if commodity.nil?

        render json: Api::V3::CommoditySerializer.new(commodity).call
      end

      def measures
        commodity = Commodity.actual.non_hidden.declarable.by_code(params[:id])
          .eager(measures: :measure_type)
          .take
        raise Sequel::RecordNotFound, "Commodity #{params[:id]} not found" if commodity.nil?

        render json: Api::V3::CommoditySerializer.measure_collection(commodity)
      end
    end
  end
end
