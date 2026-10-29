module Api
  module Admin
    module Search
      module Evaluation
        class RunsController < AdminController
          RECONCILING_STATUSES = %w[completed partially_failed failed cancelled].freeze

          # A from/to value that doesn't parse as a date (AI-1436) is a malformed request, the same
          # category of problem ActionController::ParameterMissing/OverrideValidationError already
          # render as 422 elsewhere in this app -- not a 500, which is reserved for the server's own
          # bugs, not bad input the client sent.
          rescue_from Date::Error do |exception|
            serializer = TradeTariffBackend.error_serializer(request)
            render json: serializer.serialized_errors({ error: exception.message, url: request.url }), status: :unprocessable_content
          end
          # evaluation_runs.idempotency_key is an unbounded `text` column with a unique
          # btree index on it — Postgres btree entries are capped at roughly a third of a
          # page (~2.7KB on the default 8KB page size), so a sufficiently large header
          # value would fail the INSERT with an unhandled 500 instead of a clean 400. 255
          # is generous headroom for any real idempotency key (a UUID is 36 characters)
          # while staying nowhere near that limit.
          MAX_IDEMPOTENCY_KEY_LENGTH = 255

          def index
            render json: serialize(runs.all, is_collection: true, meta: pagination_meta)
          end

          def show
            render json: serialize(run)
          end

          # The run's summary and every result as an Excel workbook (AI-1494). Built inside the
          # request, not in a background job: a run has one row per test question, so it is small.
          def export
            send_data ::Evaluation::RunWorkbook.call(run),
                      filename: "evaluation-run-#{run.id}.xlsx",
                      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                      disposition: 'attachment'
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

          # Locks the row before validating: the cancelled-is-final check compares against whatever
          # status was loaded, so without the lock a cancel saved by another request after this one
          # loaded the run would be silently overwritten.
          def update
            EvaluationRun.db.transaction do
              run.lock!
              run.set(update_params)

              if run.valid? && run.save
                run.reconcile_aggregates! if RECONCILING_STATUSES.include?(run.status)
                render json: serialize(run.reload), status: :ok
              else
                render json: serialize_errors(run), status: :unprocessable_content
              end
            end
          end

          # Deliberately scoped to runs only (AI-1441) -- not extracted into a shared
          # bulk-destroy concern other admin resources could adopt. Written cleanly enough
          # that lifting it into something reusable later would be a small refactor, but
          # building that general mechanism now, before any second resource actually needs
          # it, is out of scope.
          #
          # All-or-nothing, matching the single-run #destroy pattern on experiments: if any
          # selected run is still queued or running, the whole request is rejected and nothing
          # is deleted -- not even the other, eligible runs in the same selection. Silently
          # deleting everything except the in-progress run would leave the operator unsure
          # which of their selection actually went, and does nothing to surface that one run
          # still needs cancelling first.
          #
          # The status check and the deletes happen inside one transaction, against rows
          # locked with for_update, so both see the same, current data (AI-1441 review). The
          # earlier version read the rows with a plain `.all` outside any transaction, checked
          # their status, and only locked them later inside `each(&:destroy)` -- a PATCH
          # landing in the gap between that check and the delete could flip a selected run to
          # "running" and still have it deleted along with its results. Locking the rows before
          # checking closes that gap: any concurrent PATCH on a selected row now waits for this
          # transaction to finish first.
          def bulk_destroy
            ids = parsed_run_ids!
            in_use = false

            EvaluationRun.db.transaction do
              selected = EvaluationRun.where(id: ids).for_update.all
              if selected.any? { |run| %w[queued running].include?(run.status) }
                in_use = true
                raise Sequel::Rollback
              end

              selected.each(&:destroy)
            end

            return render_in_use if in_use

            head :no_content
          end

        private

          IN_USE_DETAIL = 'One or more selected runs are queued or running. Wait for them to finish, or cancel them, ' \
                          'then try again.'.freeze

          # Postgres's `integer` column is 4 bytes, signed (AI-1441 review). A value outside this
          # range never matches a real row -- confirmed directly against Postgres, a query like
          # `WHERE id = 99999999999999999999` just returns zero rows, not an error, so this isn't
          # guarding against a 500 the way an invalid-looking string id is. It's rejected anyway,
          # with a clear 400, because an id that can never exist at all is a different kind of
          # invalid input than one that simply doesn't match anything right now, and the caller
          # is better served knowing that than seeing it silently treated as a no-op.
          MIN_RUN_ID = -2_147_483_648
          MAX_RUN_ID = 2_147_483_647

          # Malformed input is rejected here, before it ever reaches a query:
          # - run_ids missing, or not a genuine array (e.g. a bare scalar) -- Array(params[...])
          #   would otherwise silently wrap a single stray value into a one-id selection.
          # - an element that isn't a whole number -- Integer(1.9) does not raise, it truncates
          #   to 1, so a float id would otherwise silently delete a different, real run.
          # - an element that doesn't look like an id at all -- reaches Postgres as a raw
          #   integer-column comparison and raises an unhandled 500 otherwise.
          # - an element outside Postgres's integer range -- see MIN_RUN_ID/MAX_RUN_ID above.
          def parsed_run_ids!
            raw = params[:run_ids]
            raise ActionController::BadRequest, 'run_ids must be a non-empty array' unless raw.is_a?(Array) && raw.any?

            raw.map { |id| valid_run_id!(id) }
          end

          RUN_ID_PATTERN = /\A-?\d+\z/

          def valid_run_id!(id)
            unless id.is_a?(Integer) || (id.is_a?(String) && RUN_ID_PATTERN.match?(id))
              raise ActionController::BadRequest, "run_ids must contain only integers (got #{id.inspect})"
            end

            integer = Integer(id)
            unless (MIN_RUN_ID..MAX_RUN_ID).cover?(integer)
              raise ActionController::BadRequest, "run_ids must be within the valid range (got #{id.inspect})"
            end

            integer
          end

          def render_in_use
            render json: {
              errors: [{ status: '409', title: 'Run is in use', detail: IN_USE_DETAIL }],
            }, status: :conflict
          end

          def serializer_class = Api::Admin::Search::Evaluation::RunSerializer

          def runs
            @runs ||= filtered_runs.order(Sequel.desc(:created_at)).paginate(current_page, per_page)
          end

          # from/to are parsed into locals *before* each dataset.where { } block opens, not read
          # from params inside the block itself. Sequel's virtual-row blocks rebind self to an
          # internal query-building object, so a bare `params` call inside one doesn't reach the
          # controller's own method — it resolves to a SQL identifier instead, and Date.parse
          # then raises on that object rather than on the string actually typed into the form.
          # experiment_id/status above don't have this problem because they pass a plain hash to
          # .where(...) rather than a block, so no virtual row ever rebinds self there.
          def filtered_runs
            dataset = EvaluationRun.eager(evaluation_experiment: %i[evaluation_gold_query_set evaluation_synthetic_input_set])
            dataset = dataset.where(experiment_id: params[:experiment_id]) if params[:experiment_id].present?
            dataset = dataset.where(status: params[:status]) if params[:status].present?

            if params[:from].present?
              from = parse_date_param!(:from)
              dataset = dataset.where { created_at >= from }
            end

            if params[:to].present?
              # created_at is a full timestamp; to is a bare Date (midnight at the start of that
              # day). Comparing against the start of the *next* day instead of <= to (AI-1436)
              # makes the filter include every run created any time during the to date itself,
              # not just ones created before that date's midnight.
              to = parse_date_param!(:to) + 1
              dataset = dataset.where { created_at < to }
            end

            dataset
          end

          # params[:from]/params[:to] are expected to be a plain date string. A structured value
          # (e.g. ?from[]=2026-10-13 makes this an Array) fails Date.parse with TypeError instead
          # of Date::Error, which the rescue_from above doesn't catch (AI-1436 review). Raising
          # Date::Error here for a non-String value folds that case into the same 422 path,
          # without rescuing TypeError itself, which could otherwise hide an unrelated bug
          # elsewhere in the controller.
          def parse_date_param!(key)
            value = params[key]
            raise Date::Error, "#{key} must be a date string" unless value.is_a?(String)

            Date.parse(value)
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
            if key.length > MAX_IDEMPOTENCY_KEY_LENGTH
              raise ActionController::BadRequest, "Idempotency-Key must be #{MAX_IDEMPOTENCY_KEY_LENGTH} characters or fewer"
            end

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
