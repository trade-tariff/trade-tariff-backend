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

            render json: { data: outcomes.map { |outcome| outcome[:body] } }, status: bulk_status(outcomes)
          end

        private

          def serializer_class = Api::Admin::Search::Evaluation::ResultSerializer

          def results
            @results ||= filtered_results.order(Sequel.desc(:created_at)).paginate(current_page, per_page)
          end

          def filtered_results
            dataset = EvaluationResult.dataset
            dataset = dataset.where(run_id: params[:run_id]) if params[:run_id].present?
            dataset
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

            { success: true, body: serialize(ingested)[:data] }
          rescue Sequel::NoMatchingRow, Sequel::Error => e
            { success: false, body: { error: e.message, index: } }
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
