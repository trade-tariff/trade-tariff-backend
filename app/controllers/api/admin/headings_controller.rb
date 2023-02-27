require 'goods_nomenclature_mapper'

module Api
  module Admin
    class HeadingsController < ApiController
      def show
        options = { is_collection: false }
        options[:include] = %i[commodities chapter]

        render json: Api::Admin::Headings::HeadingSerializer.new(presented_heading, options).serializable_hash
      end

      private

      def presented_heading
        Api::Admin::Headings::HeadingPresenter.new(heading, search_reference_counts)
      end

      def heading
        @heading ||= Heading.actual
                          .non_grouping
                          .non_hidden
                          .by_code(params[:id])
                          .eager(path_descendants: %i[goods_nomenclature_descriptions path_descendants])
                          .limit(1)
                          .take
      end

      def search_reference_counts
        SearchReference
          .group_and_count(:goods_nomenclature_sid)
          .where(goods_nomenclature_sid: applicable_goods_nomenclature_sids)
          .pluck(:goods_nomenclature_sid, :count)
          .to_h
      end

      def applicable_goods_nomenclature_sids
        heading.path_descendants.pluck(:goods_nomenclature_sid).tap { |sids| sids << heading.goods_nomenclature_sid }
      end
    end
  end
end
