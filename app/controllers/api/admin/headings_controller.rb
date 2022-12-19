require 'goods_nomenclature_mapper'

module Api
  module Admin
    class HeadingsController < ApiController
      before_action :find_heading, only: %i[show]

      def show
        options = { is_collection: false }
        options[:include] = %i[commodities chapter]

        render json: Api::Admin::Headings::HeadingSerializer.new(presented_heading, options).serializable_hash
      end

      private

      def find_heading
        @heading = Heading.actual
                          .non_grouping
                          .where(goods_nomenclatures__goods_nomenclature_item_id: heading_id)
                          .eager(commodities: :goods_nomenclature_descriptions)
                          .limit(1)
                          .all
                          .first

        if !@heading || @heading.goods_nomenclature_item_id.in?(HiddenGoodsNomenclature.codes)
          raise Sequel::RecordNotFound
        end
      end

      def heading_id
        "#{params[:id]}000000"
      end

      def presented_heading
        Api::Admin::Headings::HeadingPresenter.new(@heading, search_reference_counts)
      end

      def search_reference_counts
        SearchReference.count_for(@heading.commodities + [@heading])
      end
    end
  end
end
