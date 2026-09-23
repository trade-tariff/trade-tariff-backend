module Api
  module Admin
    class SearchDiagnosticRequestSerializer
      include JSONAPI::Serializer

      set_type :search_diagnostic
      set_id :request_id

      attributes :request_id, :occurred_at, :query, :experiment, :browser_session_id
    end
  end
end
