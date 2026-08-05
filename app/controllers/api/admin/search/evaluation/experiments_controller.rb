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
            experiment = EvaluationExperiment.new(experiment_params)

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

        private

          def serializer_class = Api::Admin::Search::Evaluation::ExperimentSerializer

          def experiments
            @experiments ||= EvaluationExperiment.order(:name).paginate(current_page, per_page)
          end

          def experiment
            @experiment ||= EvaluationExperiment.with_pk!(params[:id])
          end

          def experiment_params
            params.require(:data).require(:attributes).permit(
              :name, :description, :enabled, :created_by,
              configuration_overrides: {}, default_scope: {}
            ).to_h
          end

          def update_params
            params.require(:data).require(:attributes).permit(
              :description, :enabled,
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
