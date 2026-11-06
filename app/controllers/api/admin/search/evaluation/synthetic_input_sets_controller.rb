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

          # The items are not included: they have their own paginated endpoint
          # (SyntheticInputSetItemsController), because a set can hold many.
          def show
            render json: serialize(synthetic_input_set)
          end

          # Answers 409 Conflict while an experiment uses the set. The database would
          # refuse the delete anyway (a foreign key), but this way the reply says which
          # experiments to change first. The set's items are deleted with it by the
          # database (ON DELETE CASCADE).
          def destroy
            experiment_names = experiment_names_using_set
            return render_in_use(experiment_names) if experiment_names.any?

            synthetic_input_set.destroy

            head :no_content
          rescue Sequel::ForeignKeyConstraintViolation
            # An experiment began using the set after the check above. The foreign key stopped
            # the delete, so answer the same 409, naming the experiments there are now.
            render_in_use(experiment_names_using_set)
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

          def synthetic_input_set
            @synthetic_input_set ||= EvaluationSyntheticInputSet.with_pk!(params[:id])
          end

          def paginated_dataset
            @paginated_dataset ||= EvaluationSyntheticInputSet.order(Sequel.desc(:created_at), Sequel.desc(:id)).paginate(current_page, per_page)
          end

          def pagination_meta
            { pagination: { page: current_page, per_page:, total_count: paginated_dataset.pagination_record_count } }
          end

          def experiment_names_using_set
            synthetic_input_set.evaluation_experiments_dataset.order(:name).select_map(:name)
          end

          # An experiment's set is locked once chosen, so the only way to free the set is to delete
          # the experiments. That also deletes their runs and results.
          def render_in_use(experiment_names)
            render json: {
              errors: [
                {
                  status: '409',
                  title: 'Synthetic input set is in use',
                  detail: "This set cannot be deleted because these experiments use it: #{experiment_names.join(', ')}. " \
                          "An experiment's set cannot be changed, so delete those experiments first. That also deletes their runs and results.",
                },
              ],
            }, status: :conflict
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
