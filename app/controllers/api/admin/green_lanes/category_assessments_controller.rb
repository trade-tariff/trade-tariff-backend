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
          options[:meta] = pagination_meta(category_assessments)

          render json: serialize(category_assessments.to_a, options)
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

        def record_count
          @category_assessments.pagination_record_count
        end

        def category_assessments
          exemption_code = params.dig(:query, :filters, :exemption_code) || ''
          measure_type_id = params.dig(:query, :filters, :measure_type_id) || ''
          regulation_id = params.dig(:query, :filters, :regulation_id) || ''
          regulation_role = params.dig(:query, :filters, :regulation_role) || ''
          theme_id = params.dig(:query, :filters, :theme_id) || ''
          sort_by = params.dig(:query, :sort) || 'id'
          sort_order = params.dig(:query, :direction) || 'asc'

          order_expr = if sort_order == 'desc'
                         Sequel.desc(Sequel[:green_lanes_category_assessments][sort_by.to_sym])
                       else
                         Sequel.asc(Sequel[:green_lanes_category_assessments][sort_by.to_sym])
                       end

          @category_assessments ||= search_category_assessments(exemption_code, measure_type_id, regulation_id, regulation_role, theme_id, order_expr)
        end

        def search_category_assessments(exemption_code, measure_type_id, regulation_id, regulation_role, theme_id, order_expr)
          conditions = {}
          conditions[Sequel[:green_lanes_category_assessments][:measure_type_id]] = measure_type_id if measure_type_id.present?
          conditions[Sequel[:green_lanes_category_assessments][:regulation_id]] = regulation_id if regulation_id.present?
          conditions[Sequel[:green_lanes_category_assessments][:regulation_role]] = regulation_role if regulation_role.present?
          conditions[Sequel[:green_lanes_category_assessments][:theme_id]] = theme_id if theme_id.present?

          if exemption_code.blank?
            query = ::GreenLanes::CategoryAssessment.eager(:theme).order(order_expr)
            query = query.where(Sequel.|(conditions)) unless conditions.empty?
            query = query.paginate(ca_current_page, per_page)
            return query
          end

          conditions[Sequel[:exemptions][:code]] = exemption_code

          ::GreenLanes::CategoryAssessment
            .association_inner_join(:exemptions)
            .where(Sequel.|(conditions))
            .select_all(:green_lanes_category_assessments)
            .eager(:theme)
            .order(order_expr)
            .paginate(ca_current_page, per_page)
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
