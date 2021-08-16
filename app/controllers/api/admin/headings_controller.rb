module Api
  module Admin
    class HeadingsController < ApiController
      before_action :find_heading, only: [:show, :changes]

      def show
        options = { is_collection: false }
        options[:include] = [:commodities, :chapter]

        render json: Api::Admin::Headings::HeadingSerializer.new(@heading, options).serializable_hash
      end

      private

      def find_heading
        @heading = Heading.actual
                          .non_grouping
                          .where(goods_nomenclatures__goods_nomenclature_item_id: heading_id)
                          .take

        raise Sequel::RecordNotFound if @heading.goods_nomenclature_item_id.in? HiddenGoodsNomenclature.codes
      end

      def heading_id
        "#{params[:id]}000000"
      end
    end
  end
end
