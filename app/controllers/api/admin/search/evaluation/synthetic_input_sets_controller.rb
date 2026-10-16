module Api
  module Admin
    module Search
      module Evaluation
        class SyntheticInputSetsController < AdminController
          def create
            synthetic_input_set = ::Evaluation::SyntheticInputSetCreator.call(**set_params, created_by: TradeTariffRequest.whodunnit)

            if synthetic_input_set.errors.empty?
              render json: serialize(synthetic_input_set), status: :created
            else
              render json: serialize_errors(synthetic_input_set), status: :unprocessable_content
            end
          end

        private

          def serializer_class = Api::Admin::Search::Evaluation::SyntheticInputSetSerializer

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
