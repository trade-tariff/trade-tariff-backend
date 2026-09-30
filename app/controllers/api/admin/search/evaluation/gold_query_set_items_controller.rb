module Api
  module Admin
    module Search
      module Evaluation
        # The source items of one gold query set, each shown as its three persona queries.
        # See Evaluation::GoldQueryItem for how the three rows are grouped and edited.
        class GoldQuerySetItemsController < AdminController
          EDITABLE_ATTRIBUTES = [:expected_code, *::Evaluation::GoldQueryItem::PERSONAS.flat_map { |persona| %i[query notes].map { |field| :"#{persona}_#{field}" } }].freeze

          def index
            render json: serialize(page_of_items, is_collection: true, meta: pagination_meta)
          end

          def show
            render json: serialize(item)
          end

          def update
            if item.update(item_params)
              render json: serialize(item), status: :ok
            else
              render json: serialize_errors(item), status: :unprocessable_content
            end
          end

          def destroy
            item.destroy

            head :no_content
          end

          def versions
            versions = item.versions.all
            Version.preload_predecessors(versions)

            render json: Api::Admin::VersionSerializer.new(versions).serializable_hash
          end

        private

          def serializer_class = Api::Admin::Search::Evaluation::GoldQuerySetItemSerializer

          def gold_query_set
            @gold_query_set ||= EvaluationGoldQuerySet.with_pk!(params[:gold_query_set_id])
          end

          def item
            @item ||= ::Evaluation::GoldQueryItem.find(gold_query_set, params[:id])
          end

          def all_items
            @all_items ||= ::Evaluation::GoldQueryItem.for_set(gold_query_set)
          end

          def page_of_items
            all_items.slice((current_page - 1) * per_page, per_page) || []
          end

          def pagination_meta
            { pagination: { page: current_page, per_page:, total_count: all_items.size } }
          end

          # Only these are editable. Anything else in the body (the source, the oracle text,
          # the real user search that the admin app sends back unchanged) is dropped.
          def item_params
            params.require(:data).require(:attributes).permit(*EDITABLE_ATTRIBUTES).to_h.symbolize_keys
          end
        end
      end
    end
  end
end
