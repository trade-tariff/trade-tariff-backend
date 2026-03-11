module Api
  module Admin
    class DownloadSerializer
      include JSONAPI::Serializer

      set_type :apply

      set_id :id

      attributes :whodunnit, :enqueued_at
    end
  end
end
