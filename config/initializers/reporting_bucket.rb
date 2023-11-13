s3_bucket_name = ENV['AWS_REPORTING_BUCKET_NAME']
ecs_credentials_loaded = ENV['AWS_CONTAINER_CREDENTIALS_RELATIVE_URI'].present?
local_credentials_loaded = ENV['AWS_PROFILE'].present? || (ENV['AWS_SECRET_ACCESS_KEY'].present? && ENV['AWS_ACCESS_KEY_ID'])
credentials_loaded = ecs_credentials_loaded || local_credentials_loaded

s3_bucket = if Rails.env.test?
              Aws::S3::Resource.new(stub_responses: true).bucket(s3_bucket_name)
            elsif s3_bucket_name && credentials_loaded
              Aws::S3::Resource.new.bucket(s3_bucket_name)
            end

Rails.application.config.reporting_bucket = s3_bucket
