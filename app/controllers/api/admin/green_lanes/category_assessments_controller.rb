module Api
  module Admin
    module GreenLanes
      class CategoryAssessmentsController < AdminController
        include Pageable
        include XiOnly

        before_action :check_service, :authenticate_user!

        def index
          options = { is_collection: true }
          options[:include] = %i[theme]
          options[:meta] = pagination_meta(category_assessments(search_param))
          render json: serialize(category_assessments(search_param).to_a, options)
        end

        def show
          options = { is_collection: false }
          options[:include] = %i[green_lanes_measures green_lanes_measures.goods_nomenclature exemptions]

          ca = ::GreenLanes::CategoryAssessment.with_pk!(params[:id])
          options[:params] = { with_measures: true,
                               with_exemptions: true,
                               measure_pagination: measure_pagination(green_lanes_measures(ca)) }

          render json: serialize(CategoryAssessmentPresenter.new(ca, green_lanes_measures(ca).all), options)
        end

        def create
          ca = ::GreenLanes::CategoryAssessment.new(ca_params)

          if ca.valid? && ca.save
            render json: serialize(ca),
                   location: api_admin_green_lanes_category_assessment_url(ca.id),
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
                   location: api_admin_green_lanes_category_assessment_url(ca.id),
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

        def add_exemption
          ca = ::GreenLanes::CategoryAssessment.with_pk!(params[:id])
          exemption = ::GreenLanes::Exemption.with_pk!(params[:exemption_id])

          if ca.add_exemption(exemption)
            render json: serialize(ca),
                   location: api_admin_green_lanes_category_assessment_url(ca.id),
                   status: :ok
          else
            render json: serialize_errors(ca),
                   status: :unprocessable_entity
          end
        end

        def remove_exemption
          ca = ::GreenLanes::CategoryAssessment.with_pk!(params[:id])
          exemption = ::GreenLanes::Exemption.with_pk!(params[:exemption_id])

          if ca.remove_exemption(exemption)
            render json: serialize(ca),
                   location: api_admin_green_lanes_category_assessment_url(ca.id),
                   status: :ok
          else
            render json: serialize_errors(ca),
                   status: :unprocessable_entity
          end
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

        def search_param
          params.dig(:query, :exemption_code) || ''
        end

        def record_count
          @category_assessments.pagination_record_count
        end

        def category_assessments(exemption_code)
          @category_assessments ||= search_category_assessments(exemption_code)
        end

        def search_category_assessments(exemption_code)
          return ::GreenLanes::CategoryAssessment.eager(:theme).order(:id).paginate(ca_current_page, per_page) if exemption_code.blank?

          ::GreenLanes::CategoryAssessment
            .association_join(:exemptions)
            .where(
              Sequel.|(
                { Sequel[:exemptions][:code] => exemption_code },
              ),
            )
            .distinct(Sequel[:green_lanes_category_assessments][:id])
            .select_all(:green_lanes_category_assessments)
            .eager(:theme).order(Sequel[:green_lanes_category_assessments][:id]).paginate(ca_current_page, per_page)
        end

        def green_lanes_measures(category_assessment)
          category_assessment.green_lanes_measures_dataset.paginate(current_page, per_page)
        end

        def serialize(*args)
          Api::Admin::GreenLanes::CategoryAssessmentSerializer.new(*args).serializable_hash
        end

        def serialize_errors(category_assessment)
          Api::Admin::ErrorSerializationService.new(category_assessment).call
        end

        def ca_current_page
          Integer(params.dig(:query, :page) || 1)
        rescue ArgumentError
          1
        end

        def pagination_meta(data_set)
          {
            pagination: {
              page: ca_current_page,
              per_page:,
              total_count: data_set.pagination_record_count,
            },
          }
        end

        def measure_pagination(data_set)
          total_count = data_set.pagination_record_count
          {
            current_page:,
            limit_value: per_page,
            total_pages: (total_count.to_f / per_page).ceil,
          }
        end
      end
    end
  end
end
