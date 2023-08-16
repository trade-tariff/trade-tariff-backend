s3_bucket_name = ENV['SPELLING_CORRECTOR_BUCKET_NAME']
running_in_aws = ENV['ECS_AGENT_URI'].present?
credentials_loaded = ENV['AWS_PROFILE'].present? || (ENV['AWS_SECRET_ACCESS_KEY'].present? && ENV['AWS_ACCESS_KEY_ID'])

if Rails.env.test?
  s3_bucket = Aws::S3::Resource.new(stub_responses: true).bucket(s3_bucket_name)
elsif s3_bucket_name
  if running_in_aws || credentials_loaded
    s3_bucket = Aws::S3::Resource.new.bucket(s3_bucket_name)
  else
    Rails.logger.warn 'AWS credentials missing, or not running on AWS.'
  end
end

Rails.application.config.spelling_corrector_s3_bucket = s3_bucket
