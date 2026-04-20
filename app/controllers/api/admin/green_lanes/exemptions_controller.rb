module Api
  module Admin
    module GreenLanes
      class ExemptionsController < AdminController
        include Pageable
        include XiOnly
        include Api::Admin::ResourceActions

        def index
          render json: serialize(exemptions.to_a, pagination_meta)
        end

        private

        def serializer_class = Api::Admin::GreenLanes::ExemptionSerializer
        def resource_class = ::GreenLanes::Exemption

        def resource_params
          params.require(:data).require(:attributes).permit(:code, :description)
        end

        def record_count
          exemptions.pagination_record_count
        end

        def exemptions
          @exemptions ||= ::GreenLanes::Exemption.order(Sequel.asc(:code)).paginate(current_page, per_page)
        end
      end
    end
  end
end
