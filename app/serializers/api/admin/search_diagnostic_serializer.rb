module Api
  module Admin
    class SearchDiagnosticSerializer
      include JSONAPI::Serializer

      set_type :search_diagnostic
      set_id :request_id

      attributes :request_id, :log_group_name, :start_time, :end_time

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
