module Api
  module V1
    class GoodsNomenclaturesController < ApiController
      before_action :as_of, only: [:index]

      def index
        @commodities = GoodsNomenclature.actual
        response.set_header('Date', @as_of.httpdate)
        @class_determinator = GoodsNomenclature.class_determinator

        respond_to do |format|
          format.json do
            headers['Content-Type'] = 'application/json'
          end
          format.csv do
            filename = "goods_nomenclature_#{@as_of.strftime('%Y%m%d')}.csv"
            headers['Content-Type'] = 'text/csv'
            headers['Content-Disposition'] = "attachment; filename=#{filename}"
          end
        end
      end

      private

      def as_of
        @as_of ||= begin
          Date.parse(params[:as_of])
        rescue StandardError
          Date.current
        end
      end

      def api_path_builder(object)
        gnid = object.goods_nomenclature_item_id
        return nil unless gnid

        case @class_determinator.call(object)
        when 'Chapter'
          "/v1/chapters/#{gnid.first(2)}.json"
        when 'Heading'
          "/v1/headings/#{gnid.first(4)}.json"
        when 'Commodity'
          "/v1/commodities/#{gnid.first(10)}.json"
        else
          "/v1/commodities/#{gnid.first(10)}.json"
        end
      end
      helper_method :api_path_builder
    end
  end
end
