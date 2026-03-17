module Api
  module Admin
    class VersionSerializer
      include JSONAPI::Serializer

      set_type :version

      attributes :item_type, :item_id, :event, :object, :whodunnit, :created_at, :changeset, :previous_version_id
    end
  end
end
