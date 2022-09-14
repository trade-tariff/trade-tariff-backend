module Api
  module V2
    class ValidityPeriodsController < ApiController
      def index
        goods_nomenclatures_in_all_periods = goods_nomenclature_scope.exclude(validity_start_date: nil)
                                         .limit(10)
                                         .order(Sequel.desc(:validity_start_date))
                                         .to_a

        presented_goods_nomenclatures = goods_nomenclatures_in_all_periods.map do |goods_nomenclature|
          Api::V2::ValidityPeriodPresenter.new(goods_nomenclature)
        end

        serializer = Api::V2::ValidityPeriodSerializer.new(presented_goods_nomenclatures)

        render json: serializer.serializable_hash
      end

    private

      def goods_nomenclature_scope
        if params[:commodity_id].present?
          # TODO: This can include subheadings - e.g. /commodities/0101290000/validity_periods is a subheading
          Commodity.by_code(params[:commodity_id]).declarable
        elsif params[:subheading_id].present?
          code, producline_suffix = params[:subheading_id].split('-')

          Subheading.by_code(code).by_productline_suffix(producline_suffix)
        elsif params[:heading_id].present?
          Heading.by_code("#{params[:heading_id]}000000")
        else
          raise Sequel::RecordNotFound
        end
      end
    end
  end
end
