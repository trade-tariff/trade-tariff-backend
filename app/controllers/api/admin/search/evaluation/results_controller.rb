module Api
  module Admin
    module Search
      module Evaluation
        class ResultsController < AdminController
          RESULT_ATTRIBUTES = %i[
            source_type
            source_id
            persona
            expected_code
            final_code
            final_rank
            gold_in_top1
            gold_in_top5
            latency_seconds
            cost_usd
            provider_calls
            pricing_known
            error
          ].freeze

          def index
            render json: serialize(results.all, is_collection: true, meta: pagination_meta)
          end

          def show
            render json: serialize(result)
          end

          def create
            outcomes = bulk_items.map.with_index { |item, index| ingest_item(item, index) }
            reconcile_touched_runs(outcomes)

            render json: { data: outcomes.map { |outcome| outcome[:body] } }, status: bulk_status(outcomes)
          end

        private

          def serializer_class = Api::Admin::Search::Evaluation::ResultSerializer

          def results
            @results ||= filtered_results.order(Sequel.desc(:created_at)).paginate(current_page, per_page)
          end

          # outcome is derived, not a raw column: "pass" is gold_in_top5, "error" is any row whose
          # Q&A session broke (error present, regardless of gold_in_top5 -- the eval app always
          # posts gold_in_top5: false for those), and "fail" is everything else -- a genuine wrong
          # or missing classification with no session error. The three are mutually exclusive and
          # exhaustive over every result (AI-1432).
          def filtered_results
            dataset = EvaluationResult.dataset
            dataset = dataset.where(run_id: params[:run_id]) if params[:run_id].present?
            dataset = dataset.where(persona: params[:persona]) if params[:persona].present?
            filter_by_outcome(dataset)
          end

          def filter_by_outcome(dataset)
            case params[:outcome]
            when 'pass' then dataset.where(gold_in_top5: true)
            when 'fail' then dataset.exclude(gold_in_top5: true).where(error: nil)
            when 'error' then dataset.exclude(error: nil)
            else dataset
            end
          end

          def result
            @result ||= EvaluationResult.with_pk!(params[:id])
          end

          def bulk_items
            Array(params.require(:data))
          end

          def ingest_item(item, index)
            attrs = item.permit(:run_id, *RESULT_ATTRIBUTES, trace: {}).to_h
            run = EvaluationRun.with_pk!(attrs['run_id'])

            ingested = EvaluationResult.ingest!(
              run:,
              source_type: attrs['source_type'],
              source_id: attrs['source_id'],
              persona: attrs['persona'],
              attrs: attrs.except('run_id', 'source_type', 'source_id', 'persona'),
            )

            { success: true, body: serialize(ingested)[:data], run: }
          rescue Sequel::NoMatchingRow, Sequel::Error => e
            { success: false, body: { error: e.message, index: } }
          end

          # Keeps result_count/error_count live while a run is still "running", not just once it
          # reaches a terminal status (RunsController#update's own reconcile, gated on
          # RECONCILING_STATUSES) — otherwise the admin tracking page's "N of M done" is stuck at
          # 0 for the run's entire execution. Deduped by id: one bulk POST can carry several
          # results for the same run, and each is a handful of aggregate queries plus an UPDATE,
          # not worth repeating per item.
          def reconcile_touched_runs(outcomes)
            outcomes.filter_map { |outcome| outcome[:run] if outcome[:success] }.uniq(&:id).each(&:reconcile_aggregates!)
          end

          def bulk_status(outcomes)
            return :unprocessable_content if outcomes.none? { |outcome| outcome[:success] }
            return :multi_status if outcomes.any? { |outcome| !outcome[:success] }

            :ok
          end

          def pagination_meta
            { pagination: { page: current_page, per_page:, total_count: results.pagination_record_count } }
          end
        end
      end
    end
  end
end
