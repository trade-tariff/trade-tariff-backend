module Api
  module Admin
    module CustomsTariffPipeline
      class EventsController < BaseController
        def index
          page = filtered_events.paginate(current_page, per_page)

          render json: EventSerializer.new(
            page.all,
            is_collection: true,
            meta: pagination_meta(page),
          ).serializable_hash
        end

        private

        def filtered_events
          dataset = CustomsTariffPipelineEvent.most_recent_first
          dataset = apply_time_range(dataset)
          apply_exact_filters(
            dataset,
            :event_type,
            :outcome,
            :customs_tariff_update_version,
            :subject_type,
            :subject_id,
          )
        end
      end
    end
  end
end
