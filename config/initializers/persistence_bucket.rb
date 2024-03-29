s3_bucket_name = ENV['AWS_BUCKET_NAME']
running_in_aws = ENV['ECS_AGENT_URI'].present?
credentials_loaded = ENV['AWS_PROFILE'].present? || (ENV['AWS_SECRET_ACCESS_KEY'].present? && ENV['AWS_ACCESS_KEY_ID'].present?)

s3_bucket = if Rails.env.test?
              Aws::S3::Resource.new(stub_responses: true).bucket(s3_bucket_name)
            elsif s3_bucket_name && (credentials_loaded || running_in_aws)
              Aws::S3::Resource.new.bucket(s3_bucket_name)
            end

Rails.application.config.persistence_bucket = s3_bucket
