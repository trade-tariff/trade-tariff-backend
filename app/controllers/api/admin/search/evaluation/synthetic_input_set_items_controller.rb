module Api
  module Admin
    module Search
      module Evaluation
        # The items of one synthetic input set, for the admin app to page through. Read-only
        # (index only), because a set's contents are fixed when it is created.
        class SyntheticInputSetItemsController < AdminController
          def index
            render json: serialize(paginated_dataset.all, is_collection: true, meta: pagination_meta)
          end

        private

          def serializer_class = Api::Admin::Search::Evaluation::SyntheticInputSetItemSerializer

          def synthetic_input_set
            @synthetic_input_set ||= EvaluationSyntheticInputSet.with_pk!(params[:synthetic_input_set_id])
          end

          def paginated_dataset
            @paginated_dataset ||= synthetic_input_set.evaluation_synthetic_input_set_items_dataset.order(:id).paginate(current_page, per_page)
          end

          def pagination_meta
            { pagination: { page: current_page, per_page:, total_count: paginated_dataset.pagination_record_count } }
          end
        end
      end
    end
  end
end
