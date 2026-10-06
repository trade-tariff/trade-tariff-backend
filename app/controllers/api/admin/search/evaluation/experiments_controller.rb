module Api
  module Admin
    module Search
      module Evaluation
        class ExperimentsController < AdminController
          def index
            render json: serialize(experiments.all, is_collection: true, meta: pagination_meta)
          end

          def show
            render json: serialize(experiment)
          end

          def create
            experiment = EvaluationExperiment.new(experiment_params.merge(created_by: TradeTariffRequest.whodunnit))

            if experiment.valid? && experiment.save
              render json: serialize(experiment), status: :created
            else
              render json: serialize_errors(experiment), status: :unprocessable_content
            end
          end

          def update
            experiment.set(update_params)

            if experiment.valid? && experiment.save
              render json: serialize(experiment), status: :ok
            else
              render json: serialize_errors(experiment), status: :unprocessable_content
            end
          end

          # Refused while a run is still executing: deleting it would remove the run out from under
          # the eval app, which would then fail every result post and its final status write.
          # Finished runs don't block the delete and are removed with the experiment.
          def destroy
            return render_in_use if experiment.evaluation_runs_dataset.where(status: %w[queued running]).any?

            experiment.destroy
            head :no_content
          end

        private

          IN_USE_DETAIL = 'This experiment cannot be deleted while one of its runs is queued or running. ' \
                          'Wait for the run to finish, or cancel it, then try again.'.freeze

          def render_in_use
            render json: {
              errors: [{ status: '409', title: 'Experiment is in use', detail: IN_USE_DETAIL }],
            }, status: :conflict
          end

          def serializer_class = Api::Admin::Search::Evaluation::ExperimentSerializer

          def experiments
            @experiments ||= EvaluationExperiment.order(:name).paginate(current_page, per_page)
          end

          def experiment
            @experiment ||= EvaluationExperiment.with_pk!(params[:id])
          end

          def experiment_params
            params.require(:data).require(:attributes).permit(
              :name, :description, :enabled, :gold_query_set_id,
              configuration_overrides: {}, default_scope: {}
            ).to_h
          end

          def update_params
            params.require(:data).require(:attributes).permit(
              :description, :enabled, :gold_query_set_id,
              configuration_overrides: {}, default_scope: {}
            ).to_h
          end

          def pagination_meta
            { pagination: { page: current_page, per_page:, total_count: experiments.pagination_record_count } }
          end
        end
      end
    end
  end
end
