module Api
  module Admin
    class GoodsNomenclatureLabelsController < AdminController
      def index
        render json: serialized_collection
      end

      private

      def serialized_collection
        GoodsNomenclatures::GoodsNomenclatureLabelSerializer.new(
          paginated_dataset.all,
          is_collection: true,
          meta: pagination_meta,
        ).serializable_hash
      end

      def pagination_meta
        {
          pagination: {
            page: current_page,
            per_page:,
            total_count: paginated_dataset.pagination_record_count,
          },
        }
      end

      def paginated_dataset
        @paginated_dataset ||= search_dataset.paginate(current_page, per_page)
      end

      def search_dataset
        q = params[:q].to_s.strip
        return empty_dataset if q.length < 2

        dataset = TimeMachine.now { GoodsNomenclatureLabel.actual }

        if q.match?(/\A\d{2,10}\z/)
          dataset.where(Sequel.like(:goods_nomenclature_item_id, "#{q}%"))
                 .order(:goods_nomenclature_item_id)
        else
          term = "%#{q}%"
          dataset.where(
            Sequel.ilike(Sequel.lit('labels::text'), term),
          ).order(:goods_nomenclature_item_id)
        end
      end

      def empty_dataset
        TimeMachine.now { GoodsNomenclatureLabel.actual.where(Sequel.lit('1=0')) }
      end
    end
  end
end
