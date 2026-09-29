module Api
  module Admin
    module Search
      module Evaluation
        class GoldQuerySetsController < AdminController
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
