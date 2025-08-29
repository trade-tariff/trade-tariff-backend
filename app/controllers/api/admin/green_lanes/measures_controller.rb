module Api
  module Admin
    module GreenLanes
      class MeasuresController < AdminController
        include Pageable
        include XiOnly

        MEASURE_EAGER_GRAPH = {
          category_assessment: :theme,
          goods_nomenclature: :goods_nomenclature_descriptions,
        }.freeze

        before_action :check_service, :authenticate_user!

        def index
          options = { is_collection: true }
          options[:include] = %i[category_assessment category_assessment.theme goods_nomenclature]
          options[:meta] = pagination_meta(measures)
          render json: serialize(measures.to_a, options)
        end

        def show
          options = { is_collection: false }
          options[:include] = %i[category_assessment]
          measure = ::GreenLanes::Measure.with_pk!(params[:id])
          render json: serialize(measure, options)
        end

        def create
          gn = GoodsNomenclature.actual.where(goods_nomenclature_item_id: measure_params[:goods_nomenclature_item_id],
                                              producline_suffix: measure_params[:productline_suffix])

          if gn.present?
            measure = ::GreenLanes::Measure.new(measure_params)

            if gn.present? && measure.valid? && measure.save
              render json: serialize(measure),
                     status: :created
            else
              render json: serialize_errors(measure),
                     status: :unprocessable_content
            end
          else
            raise Sequel::RecordNotFound
          end
        end

        def update
          measure = ::GreenLanes::Measure.with_pk!(params[:id])
          measure.set measure_params

          if measure.valid? && measure.save
            render json: serialize(measure),
                   status: :ok
          else
            render json: serialize_errors(measure),
                   status: :unprocessable_content
          end
        end

        def destroy
          measure = ::GreenLanes::Measure.with_pk!(params[:id])
          measure.destroy

          head :no_content
        end

        private

        def measures
          @measures ||= ::GreenLanes::Measure.eager(MEASURE_EAGER_GRAPH).order.paginate(current_page, per_page)
        end

        def measure_params
          params.require(:data).require(:attributes).permit(
            :category_assessment_id,
            :goods_nomenclature_item_id,
            :productline_suffix,
          )
        end

        def record_count
          @measures.pagination_record_count
        end

        def serialize(*args)
          Api::Admin::GreenLanes::MeasureSerializer.new(*args).serializable_hash
        end

        def serialize_errors(measure)
          Api::Admin::ErrorSerializationService.new(measure).call
        end

        def pagination_meta(data_set)
          {
            pagination: {
              page: current_page,
              per_page:,
              total_count: data_set.pagination_record_count,
            },
          }
        end
      end
    end
  end
end
