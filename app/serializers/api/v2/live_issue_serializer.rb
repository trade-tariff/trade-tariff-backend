module Api
  module V2
    class LiveIssueSerializer
      include JSONAPI::Serializer

      set_type :live_issue

      set_id :id

      attributes :title,
                  :description,
                  :commodities,
                  :status,
                  :date_discovered,
                  :date_resolved,
                  :updated_at
    end
  end
end
