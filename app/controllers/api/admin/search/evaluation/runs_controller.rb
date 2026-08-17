module Api
  module Admin
    module Search
      module Evaluation
        class RunsController < AdminController
          RECONCILING_STATUSES = %w[completed partially_failed failed cancelled].freeze

          def index
            render json: serialize(runs.all, is_collection: true, meta: pagination_meta)
          end

          def show
            render json: serialize(run)
          end

          def create
            experiment = EvaluationExperiment.with_pk!(create_params[:experiment_id])

            evaluation_run = EvaluationRun.start!(
              experiment:,
              triggered_by: create_params[:triggered_by],
              idempotency_key: idempotency_key!,
              run_time_overrides: create_params[:configuration_overrides] || {},
            )

            render json: serialize(evaluation_run), status: :created
          end

          def update
            run.set(update_params)

            if run.valid? && run.save
              run.reconcile_aggregates! if RECONCILING_STATUSES.include?(run.status)
              render json: serialize(run.reload), status: :ok
            else
              render json: serialize_errors(run), status: :unprocessable_content
            end
          end

        private

          def serializer_class = Api::Admin::Search::Evaluation::RunSerializer

          def runs
            @runs ||= filtered_runs.order(Sequel.desc(:created_at)).paginate(current_page, per_page)
          end

          def filtered_runs
            dataset = EvaluationRun.dataset
            dataset = dataset.where(experiment_id: params[:experiment_id]) if params[:experiment_id].present?
            dataset = dataset.where(status: params[:status]) if params[:status].present?
            dataset = dataset.where { created_at >= Date.parse(params[:from]) } if params[:from].present?
            dataset = dataset.where { created_at <= Date.parse(params[:to]) } if params[:to].present?
            dataset
          end

          def run
            @run ||= EvaluationRun.with_pk!(params[:id])
          end

          # Required so retrying a create request (timeout, dropped response) can be
          # told apart from a deliberate second run of the same experiment — see
          # EvaluationRun.start!.
          def idempotency_key!
            key = request.headers['Idempotency-Key']
            raise ActionController::BadRequest, 'Idempotency-Key header is required' if key.blank?

            key
          end

          def create_params
            params.require(:data).require(:attributes).permit(:experiment_id, :triggered_by, configuration_overrides: {}).to_h
          end

          def update_params
            params.require(:data).require(:attributes).permit(:status, :completed_at, :error_summary).to_h
          end

          def pagination_meta
            { pagination: { page: current_page, per_page:, total_count: runs.pagination_record_count } }
          end
        end
      end
    end
  end
end
