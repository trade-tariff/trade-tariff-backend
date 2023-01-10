s3_bucket_name = ENV['SPELLING_CORRECTOR_BUCKET_NAME']

s3_bucket = if Rails.env.test? && s3_bucket_name
              Aws::S3::Resource.new(stub_responses: true).bucket(s3_bucket_name)

            else
              Aws::S3::Resource.new.bucket(s3_bucket_name)

            end

Rails.application.config.spelling_corrector_s3_bucket = s3_bucket
