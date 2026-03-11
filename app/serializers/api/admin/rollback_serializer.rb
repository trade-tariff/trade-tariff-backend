module Api
  module Admin
    class RollbackSerializer
      include JSONAPI::Serializer

      set_type :rollback

      set_id :id

      attributes :whodunnit, :reason, :date, :keep, :enqueued_at
    end
  end
end
