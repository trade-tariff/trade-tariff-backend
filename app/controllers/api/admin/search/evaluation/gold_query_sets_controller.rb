module Api
  module Admin
    module Search
      module Evaluation
        class GoldQuerySetsController < AdminController
          def index
            gold_query_sets = paginated_dataset.all

            render json: serialize(
              gold_query_sets,
              is_collection: true,
              params: { item_counts: item_counts_for(gold_query_sets), gold_query_counts: gold_query_counts_for(gold_query_sets) },
              meta: pagination_meta,
            )
          end

          def show
            render json: serialize(gold_query_set, params: { item_counts: item_counts_for([gold_query_set]), gold_query_counts: gold_query_counts_for([gold_query_set]) })
          end

          # Answers 409 Conflict while an experiment uses the set. The database would
          # refuse the delete anyway (a foreign key), but this way the reply says which
          # experiments to change first.
          def destroy
            experiment_names = gold_query_set.evaluation_experiments_dataset.order(:name).select_map(:name)
            return render_in_use(experiment_names) if experiment_names.any?

            gold_query_set.destroy

            head :no_content
          end

          # Answers 202 Accepted, not 201 Created. The set exists, but the model is still
          # generating its gold queries in the background. Read its status and counters
          # to follow progress.
          def create
            gold_query_set = ::Evaluation::GoldQuerySetCreator.call(**set_params, created_by: TradeTariffRequest.whodunnit)

            if gold_query_set.errors.empty?
              render json: serialize(gold_query_set), status: :accepted
            else
              render json: serialize_errors(gold_query_set), status: :unprocessable_content
            end
          end

        private

          def serializer_class = Api::Admin::Search::Evaluation::GoldQuerySetSerializer

          def gold_query_set
            @gold_query_set ||= EvaluationGoldQuerySet.with_pk!(params[:id])
          end

          def paginated_dataset
            @paginated_dataset ||= EvaluationGoldQuerySet.order(Sequel.desc(:created_at), Sequel.desc(:id)).paginate(current_page, per_page)
          end

          def item_counts_for(gold_query_sets)
            EvaluationGoldQuerySet.item_counts(gold_query_sets.map(&:id))
          end

          def gold_query_counts_for(gold_query_sets)
            EvaluationGoldQuerySet.gold_query_counts(gold_query_sets.map(&:id))
          end

          def pagination_meta
            { pagination: { page: current_page, per_page:, total_count: paginated_dataset.pagination_record_count } }
          end

          def render_in_use(experiment_names)
            render json: {
              errors: [
                {
                  status: '409',
                  title: 'Gold query set is in use',
                  detail: "This set cannot be deleted because these experiments use it: #{experiment_names.join(', ')}. Point them at another set first.",
                },
              ],
            }, status: :conflict
          end

          # created_by is deliberately not accepted from the body. It comes from the
          # X-Whodunnit header, the same as for experiments.
          def set_params
            attributes = params.require(:data).require(:attributes).permit(:name, :requested_size, :atar_percentage)

            { name: attributes[:name], requested_size: attributes[:requested_size], atar_percentage: attributes[:atar_percentage] }
          end
        end
      end
    end
  end
end
