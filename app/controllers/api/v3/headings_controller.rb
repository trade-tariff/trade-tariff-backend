module Api
  module V3
    class HeadingsController < BaseController
      def show
        heading = Heading.actual.non_grouping.non_hidden.by_code(heading_code).take
        raise Sequel::RecordNotFound, "Heading #{heading_code} not found" if heading.nil?

        render json: Api::V3::HeadingSerializer.new(heading).call
      end

      def commodities
        heading = Heading.actual.non_grouping.non_hidden.by_code(heading_code)
          .eager(descendants: :goods_nomenclature_descriptions)
          .take
        raise Sequel::RecordNotFound, "Heading #{heading_code} not found" if heading.nil?

        render json: Api::V3::HeadingSerializer.commodity_collection(heading.descendants)
      end

    private

      def heading_code
        params[:id].to_s.ljust(10, '0')
      end
    end
  end
end
