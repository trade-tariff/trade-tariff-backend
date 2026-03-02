module Api
  module Admin
    class GoodsNomenclatureSelfTextsController < AdminController
      def index
        render json: serialized_collection
      end

      private

      def serialized_collection
        GoodsNomenclatures::GoodsNomenclatureSelfTextSerializer.new(
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
        @paginated_dataset ||= filtered_dataset.paginate(current_page, per_page)
      end

      def filtered_dataset
        dataset = GoodsNomenclatureSelfText
          .admin_listing
          .search(params[:q])
          .for_nomenclature_type(params[:type])
          .for_status(params[:status])
          .for_score_category(params[:score_category])

        apply_sorting(dataset)
      end

      def apply_sorting(dataset)
        col = sort_column
        dir = sort_direction == 'desc' ? :desc : :asc

        dataset.order(Sequel.public_send(dir, col, nulls: :last))
      end

      def sort_column
        allowed = {
          'score' => Sequel.lit('score'),
          'goods_nomenclature_item_id' => Sequel[:goods_nomenclature_self_texts][:goods_nomenclature_item_id],
        }

        allowed[params[:sort]] || Sequel.lit('score')
      end

      def sort_direction
        %w[asc desc].include?(params[:direction]) ? params[:direction] : 'asc'
      end
    end
  end
end
