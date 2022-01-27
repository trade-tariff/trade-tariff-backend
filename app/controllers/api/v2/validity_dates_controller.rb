module Api
  module V2
    class ValidityDatesController < ApiController
      def index
        items_in_all_periods = item_scope.limit(10)
                                         .order(Sequel.desc(:validity_start_date))
                                         .to_a

        presented_items = items_in_all_periods.map do |item|
          Api::V2::ValidityDatePresenter.new item
        end

        serializer = Api::V2::ValidityDateSerializer.new(presented_items)

        render json: serializer.serializable_hash
      end

    private

      def item_scope
        if params[:commodity_id].present?
          Commodity.by_code(params[:commodity_id]).declarable
        elsif params[:heading_id].present?
          Heading.by_code("#{params[:heading_id]}000000")
        else
          raise Sequel::RecordNotFound
        end
      end
    end
  end
end
