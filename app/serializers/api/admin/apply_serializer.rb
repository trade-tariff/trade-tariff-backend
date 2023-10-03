module Api
  module Admin
    class ApplySerializer
      include JSONAPI::Serializer

      set_type :apply

      set_id :id

      attributes :user_id, :enqueued_at
    end
  end
end
