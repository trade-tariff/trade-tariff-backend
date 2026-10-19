module Api
  module Admin
    module Search
      module Evaluation
        class SyntheticInputSetsController < AdminController
          # For the experiment form's picker (AI-1452), the same way GoldQuerySetsController#index
          # serves the equivalent gold query set picker.
          def index
            render json: serialize(paginated_dataset.all, is_collection: true, meta: pagination_meta)
          end

          def create
            synthetic_input_set = ::Evaluation::SyntheticInputSetCreator.call(**set_params, created_by: TradeTariffRequest.whodunnit)

            if synthetic_input_set.errors.empty?
              render json: serialize(synthetic_input_set, params: { with_items: true }), status: :created
            else
              render json: serialize_errors(synthetic_input_set), status: :unprocessable_content
            end
          end

        private

          def serializer_class = Api::Admin::Search::Evaluation::SyntheticInputSetSerializer

          def paginated_dataset
            @paginated_dataset ||= EvaluationSyntheticInputSet.order(Sequel.desc(:created_at), Sequel.desc(:id)).paginate(current_page, per_page)
          end

          def pagination_meta
            { pagination: { page: current_page, per_page:, total_count: paginated_dataset.pagination_record_count } }
          end

          # created_by is deliberately not accepted from the body. It comes from the
          # X-Whodunnit header, the same as for gold query sets and experiments.
          def set_params
            attributes = params.require(:data).require(:attributes).permit(:name, :requested_size)

            { name: attributes[:name], requested_size: attributes[:requested_size] }
          end
        end
      end
    end
  end
end
