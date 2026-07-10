module Api
  module V3
    class SubheadingsController < BaseController
      def show
        subheading = Subheading.actual
                               .non_hidden
                               .by_code(params[:id])
                               .take
        raise Sequel::RecordNotFound, "Subheading #{params[:id]} not found" if subheading.nil?

        render json: Api::V3::SubheadingSerializer.new(subheading).call
      end

      def commodities
        subheading = Subheading.actual
                               .non_hidden
                               .by_code(params[:id])
                               .eager(descendants: :goods_nomenclature_descriptions)
                               .take
        raise Sequel::RecordNotFound, "Subheading #{params[:id]} not found" if subheading.nil?

        render json: Api::V3::SubheadingSerializer.commodity_collection(subheading.descendants)
      end
    end
  end
end
