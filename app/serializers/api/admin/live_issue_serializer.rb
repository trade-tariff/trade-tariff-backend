module Api
  module Admin
    class LiveIssueSerializer
      include JSONAPI::Serializer

      set_type :live_issue

      set_id :id

      attributes :title,
                  :description,
                  :suggested_action,
                  :commodities,
                  :status,
                  :date_discovered,
                  :date_resolved,
                  :updated_at
    end
  end
end
