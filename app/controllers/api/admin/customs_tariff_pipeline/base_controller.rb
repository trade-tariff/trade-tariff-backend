module Api
  module Admin
    module CustomsTariffPipeline
      class BaseController < AdminController
        private

        def pagination_meta(dataset)
          {
            pagination: {
              page: current_page,
              per_page:,
              total_count: dataset.pagination_record_count,
            },
          }
        end

        def parsed_time_param(name)
          return if params[name].blank?

          Time.zone.parse(params[name])
        rescue ArgumentError, TypeError
          raise ActionController::BadRequest, "#{name} must be a valid ISO 8601 time"
        end

        def apply_time_range(dataset, column: nil)
          from_time = parsed_time_param(:from)
          to_time = parsed_time_param(:to)

          dataset = column ? dataset.where { Sequel[column] >= from_time } : dataset.from_time(from_time) if from_time
          dataset = column ? dataset.where { Sequel[column] <= to_time } : dataset.to_time(to_time) if to_time
          dataset
        end

        def apply_exact_filters(dataset, *names)
          names.each do |name|
            dataset = dataset.where(name => params[name]) if params[name].present?
          end

          dataset
        end
      end
    end
  end
end
