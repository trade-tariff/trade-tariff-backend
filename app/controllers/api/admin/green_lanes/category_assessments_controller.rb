module Api
  module Admin
    module GreenLanes
      class CategoryAssessmentsController < AdminController
        include Pageable

        before_action :check_service, :authenticate_user!

        def index
          render json: serialize(category_assessments.to_a, pagination_meta)
        end

        def show
          ca = ::GreenLanes::CategoryAssessment.with_pk!(params[:id])
          render json: serialize(ca)
        end

        def create
          ca = ::GreenLanes::CategoryAssessment.new(ca_params)

          if ca.valid? && ca.save
            render json: serialize(ca),
                   location: api_admin_category_assessment_url(ca.id),
                   status: :created
          else
            render json: serialize_errors(ca),
                   status: :unprocessable_entity
          end
        end

        def update
          ca = ::GreenLanes::CategoryAssessment.with_pk!(params[:id])
          ca.set ca_params

          if ca.valid? && ca.save
            render json: serialize(ca),
                   location: api_admin_category_assessment_url(ca.id),
                   status: :ok
          else
            render json: serialize_errors(ca),
                   status: :unprocessable_entity
          end
        end

        def destroy
          ca = ::GreenLanes::CategoryAssessment.with_pk!(params[:id])
          ca.destroy

          head :no_content
        end

        private

        def ca_params
          params.require(:data).require(:attributes).permit(
            :regulation_id,
            :regulation_role,
            :measure_type_id,
            :theme_id,
          )
        end

        def record_count
          @category_assessments.pagination_record_count
        end

        def category_assessments
          @category_assessments ||= ::GreenLanes::CategoryAssessment.order(Sequel.desc(:id)).paginate(current_page, per_page)
        end

        def serialize(*args)
          Api::Admin::GreenLanes::CategoryAssessmentSerializer.new(*args).serializable_hash
        end

        def serialize_errors(category_assessment)
          Api::Admin::ErrorSerializationService.new(category_assessment).call
        end

        def check_service
          if TradeTariffBackend.uk?
            raise ActionController::RoutingError, 'Invalid service'
          end
        end
      end
    end
  end
end
