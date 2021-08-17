object false

child @collection => :updates do
  attributes :update_type,
             :state,
             :created_at,
             :updated_at,
             :filename,
             :applied_at,
             :filesize,
             :exception_backtrace,
             :exception_queries,
             :exception_class,
             :file_presigned_url

  child presence_errors: :presence_errors do
    attributes :model_name, :details
  end
end

extends 'api/v1/shared/pagination'
