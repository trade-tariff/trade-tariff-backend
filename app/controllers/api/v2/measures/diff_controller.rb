module Api
  module V2
    module Measures
      class DiffController < ApiController
        before_action :validate_dates

        def index
          render json: Api::V2::Measures::DiffSerializer.new(
            operations,
            meta: response_meta,
          ).serializable_hash
        end

      private

        def operations
          Measure::Operation
            .where(operation_date: from_date..to_date)
            .order(Sequel.desc(:operation_date), :measure_sid)
            .paginate(current_page, per_page, record_count)
            .all
        end

        def record_count
          @record_count ||= Measure::Operation.where(operation_date: from_date..to_date).count
        end

        def response_meta
          {
            from_date: from_date.iso8601,
            to_date: to_date.iso8601,
            pagination: {
              page: current_page,
              per_page:,
              total_count: record_count,
            },
          }
        end

        def validate_dates
          raise ActionController::ParameterMissing, :from_date if params[:from_date].blank?
          raise ActionController::BadRequest, 'to_date cannot be before from_date' if to_date < from_date
        end

        def from_date
          @from_date ||= Date.parse(params[:from_date])
        rescue ArgumentError
          raise ActionController::BadRequest, 'from_date must be a valid date (YYYY-MM-DD)'
        end

        def to_date
          @to_date ||= params[:to_date].present? ? Date.parse(params[:to_date]) : Date.current
        rescue ArgumentError
          raise ActionController::BadRequest, 'to_date must be a valid date (YYYY-MM-DD)'
        end

        def per_page
          Integer(params[:per_page] || 25).clamp(1, 100)
        rescue ArgumentError
          25
        end
      end
    end
  end
end
