object false

child @collection => :updates do
  attributes :update_type, :state, :created_at, :updated_at, :filename, :applied_at, :filesize, :exception_backtrace,
             :exception_queries, :exception_class, :file_presigned_url

  child :conformance_errors => :conformance_errors do
    attributes :model_name, :model_primary_key, :model_values, :model_conformance_errors
  end

  child :presence_errors => :presence_errors do
    attributes :model_name, :details
  end
end

extends 'api/v1/shared/pagination'
