module Api
  module User
    class DataExportSerializer
      include JSONAPI::Serializer

      set_type :data_export

      set_id :id

      attributes :status, :export_type, :file_name, :s3_key, :created_at, :updated_at
    end
  end
end
