s3_bucket_name = ENV['SPELLING_CORRECTOR_BUCKET_NAME']
credentials_loaded = ENV['AWS_PROFILE'].present? || (ENV['AWS_SECRET_ACCESS_KEY'].present? && ENV['AWS_ACCESS_KEY_ID'])

s3_bucket = if Rails.env.test?
              Aws::S3::Resource.new(stub_responses: true).bucket(s3_bucket_name)
            elsif s3_bucket_name && credentials_loaded
              Aws::S3::Resource.new.bucket(s3_bucket_name)
            end

Rails.application.config.spelling_corrector_s3_bucket = s3_bucket
