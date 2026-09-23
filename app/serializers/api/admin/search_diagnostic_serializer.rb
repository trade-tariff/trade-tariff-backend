module Api
  module Admin
    class SearchDiagnosticSerializer
      include JSONAPI::Serializer

      set_type :search_diagnostic
      set_id :request_id

      attributes :request_id, :log_group_name, :start_time, :end_time, :experiment, :browser_session_id

      attribute :related_requests do |diagnostic|
        Array(diagnostic.related_requests).map do |request|
          {
            request_id: request.request_id,
            occurred_at: request.occurred_at,
            query: request.query,
            experiment: request.experiment,
            browser_session_id: request.browser_session_id,
          }
        end
      end

      attribute :events do |diagnostic|
        diagnostic.events.map do |event|
          {
            timestamp: event.timestamp,
            event: event.event,
            search_type: event.search_type,
            message: event.message,
            fields: event.fields,
          }
        end
      end
    end
  end
end
