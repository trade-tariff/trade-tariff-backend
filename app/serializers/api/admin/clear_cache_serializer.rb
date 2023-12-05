module Api
  module Admin
    class ClearCacheSerializer
      include JSONAPI::Serializer

      set_type :clear_cache

      set_id :id

      attributes :user_id, :enqueued_at
    end
  end
end
